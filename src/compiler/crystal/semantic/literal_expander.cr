module Crystal
  class LiteralExpander
    def initialize(@program)
      @regexes = [] of {String, Regex::Options}
    end

    # Convert an array literal to creating an Array and storing the values:
    #
    # From:
    #
    #     [] of T
    #
    # To:
    #
    #     Array(T).new
    #
    # From:
    #
    #     [1, 2, 3]
    #
    # To:
    #
    #     ary = Array(typeof(1, 2, 3)).new(3)
    #     ary.length = 3
    #     buffer = ary.buffer
    #     buffer[0] = 1
    #     buffer[1] = 2
    #     buffer[2] = 3
    #     ary
    def expand(node : ArrayLiteral)
      if node_of = node.of
        if node.elements.length == 0
          generic = Generic.new(Path.global("Array"), node_of).at(node)
          call = Call.new(generic, "new").at(node)
          return call
        end

        type_var = node_of
      else
        type_var = TypeOf.new(node.elements.clone)
      end

      length = node.elements.length
      capacity = length

      generic = Generic.new(Path.global("Array"), type_var).at(node)
      constructor = Call.new(generic, "new", NumberLiteral.new(capacity)).at(node)

      temp_var = new_temp_var
      assign = Assign.new(temp_var.clone, constructor).at(node)

      set_length = Call.new(temp_var.clone, "length=", NumberLiteral.new(length)).at(node)
      get_buffer = Call.new(temp_var.clone, "buffer").at(node)

      buffer = new_temp_var.at(node)

      assign_buffer = Assign.new(buffer.clone, get_buffer).at(node)

      exps = Array(ASTNode).new(node.elements.length + 4)
      exps.push assign, set_length, assign_buffer
      node.elements.each_with_index do |elem, i|
        exps << Call.new(buffer.clone, "[]=", NumberLiteral.new(i), elem).at(node)
      end
      exps << temp_var.clone

      Expressions.new(exps).at(node)
    end

    def expand_named(node : ArrayLiteral)
      temp_var = new_temp_var

      constructor = Call.new(node.name, "new").at(node)

      if node.elements.empty?
        return constructor
      end

      exps = Array(ASTNode).new(node.elements.length + 2)
      exps << Assign.new(temp_var.clone, constructor).at(node)
      node.elements.each do |elem|
        exps << Call.new(temp_var.clone, "<<", elem).at(node)
      end
      exps << temp_var.clone

      Expressions.new(exps).at(node)
    end

    def expand_named(node : HashLiteral)
      constructor = Call.new(node.name, "new").at(node)

      if node.entries.empty?
        return constructor
      end

      temp_var = new_temp_var

      exps = Array(ASTNode).new(node.entries.length + 2)
      exps << Assign.new(temp_var.clone, constructor).at(node)
      node.entries.each do |entry|
        exps << Call.new(temp_var.clone, "[]=", [entry.key.clone, entry.value.clone]).at(node)
      end
      exps << temp_var.clone

      Expressions.new(exps).at(node)
    end

    # Convert a HashLiteral into creating a Hash and assigning keys and values:
    #
    # From:
    #
    #     {} of K => V
    #
    # To:
    #
    #     Hash(K, V).new
    #
    # From:
    #
    #     {a => b, c => d}
    #
    # To:
    #
    #     hash = Hash(typeof(a, c), typeof(b, d)).new
    #     hash[a] = b
    #     hash[c] = d
    #     hash
    def expand(node : HashLiteral)
      if of = node.of
        type_vars = [of.key, of.value] of ASTNode
      else
        typeof_key = TypeOf.new(node.entries.map &.key.clone).at(node)
        typeof_value = TypeOf.new(node.entries.map &.value.clone).at(node)
        type_vars = [typeof_key, typeof_value] of ASTNode
      end

      generic = Generic.new(Path.global("Hash"), type_vars).at(node)
      constructor = Call.new(generic, "new").at(node)

      if node.entries.empty?
        constructor
      else
        temp_var = new_temp_var

        exps = Array(ASTNode).new(node.entries.length + 2)
        exps << Assign.new(temp_var.clone, constructor).at(node)
        node.entries.each do |entry|
          exps << Call.new(temp_var.clone, "[]=", entry.key.clone, entry.value.clone).at(node)
        end
        exps << temp_var.clone
        Expressions.new(exps).at(node)
      end
    end

    # From:
    #
    #     /regex/flags
    #
    # To:
    #
    #     if temp_var = $some_global
    #       temp_var
    #     else
    #       $some_global = Regex.new("regex", Regex::Options.new(flags))
    #     end
    #
    # That is, cache the regex in a global variable.
    #
    # Only do this for regex literals that don't contain interpolation.
    #
    # If there's an interpolation, expand to: Regex.new(interpolation, flags)
    def expand(node : RegexLiteral)
      node_value = node.value
      case node_value
      when StringLiteral
        string = node_value.value

        key = {string, node.options}
        index = @regexes.index key
        unless index
          index = @regexes.length
          @regexes << key
        end

        global_name = "$Regex:#{index}"
        temp_name = @program.new_temp_var_name
        @program.initialized_global_vars.add global_name
        first_assign = Assign.new(Var.new(temp_name), Global.new(global_name))
        regex = regex_new_call(node, StringLiteral.new(string))
        second_assign = Assign.new(Global.new(global_name), regex)
        If.new(first_assign, Var.new(temp_name), second_assign)
      else
        regex_new_call(node, node_value)
      end
    end

    # Convert and to if:
    #
    # From:
    #
    #     a && b
    #
    # To:
    #
    #     if temp = a
    #       b
    #     else
    #       temp
    #     end
    def expand(node : And)
      left = node.left

      if left.is_a?(Expressions) && left.expressions.length == 1
        left = left.expressions.first
      end

      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
               If.new(left, node.right, left.clone)
             elsif left.is_a?(Assign) && left.target.is_a?(Var)
               If.new(left, node.right, left.target.clone)
             else
               temp_var = new_temp_var
               If.new(Assign.new(temp_var.clone, left), node.right, temp_var.clone)
             end
      new_node.binary = :and
      new_node.location = node.location
      new_node
    end

    # Convert or to if
    #
    # From:
    #
    #     a || b
    #
    # To:
    #
    #     if temp = a
    #       temp
    #     else
    #       b
    #     end
    def expand(node : Or)
      left = node.left

      if left.is_a?(Expressions) && left.expressions.length == 1
        left = left.expressions.first
      end

      new_node = if left.is_a?(Var)
                   If.new(left, left.clone, node.right)
                 elsif left.is_a?(Assign) && left.target.is_a?(Var)
                   If.new(left, left.target.clone, node.right)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var.clone, left), temp_var.clone, node.right)
                 end
      new_node.binary = :or
      new_node.location = node.location
      new_node
    end

    # Transform a range literal into creating a Range object.
    #
    # From:
    #
    #    1 .. 3
    #
    # To:
    #
    #    Range.new(1, 3, true)
    #
    # From:
    #
    #    1 ... 3
    #
    # To:
    #
    #    Range.new(1, 3, false)
    def expand(node : RangeLiteral)
      path = Path.global("Range").at(node)
      bool = BoolLiteral.new(node.exclusive).at(node)
      Call.new(path, "new", [node.from, node.to, bool]).at(node)
    end

    # Convert an interpolation to a concatenation with a StringIO:
    #
    # From:
    #
    #     "foo#{bar}baz"
    #
    # To:
    #
    #     (StringIO.new << "foo" << bar << "baz").to_s
    def expand(node : StringInterpolation)
      # Compute how long at least the string will be, so we
      # can allocate enough space.
      capacity = 0
      node.expressions.each do |piece|
        case piece
        when StringLiteral
          capacity += piece.value.length
        else
          capacity += 15
        end
      end

      if capacity <= 64
        call = Call.new(Path.global(["String", "Builder"]), "new")
      else
        call = Call.new(Path.global(["String", "Builder"]), "new", NumberLiteral.new(capacity))
      end

      node.expressions.each do |piece|
        call = Call.new(call, "<<", piece)
      end
      Call.new(call, "to_s").at(node)
    end

    # Convert a Case into a series of if ... elseif ... end:
    #
    # From:
    #
    #     case foo
    #     when bar, baz
    #       1
    #     when bun
    #       2
    #     else
    #       3
    #     end
    #
    # To:
    #
    #     temp = foo
    #     if bar === temp || baz === temp
    #       1
    #     elsif bun === temp
    #       2
    #     else
    #       3
    #     end
    #
    # But, when the "when" has a constant name, it's transformed to is_a?:
    #
    # From:
    #
    #     case foo
    #     when Bar
    #       1
    #     end
    #
    # To:
    #
    #     temp = foo
    #     if temp.is_a?(Bar)
    #       1
    #     end
    def expand(node : Case)
      node_cond = node.cond
      if node_cond
        case node_cond
        when Var, InstanceVar
          temp_var = node.cond
        when Assign
          temp_var = node_cond.target
          assign = node_cond
        else
          temp_var = new_temp_var
          assign = Assign.new(temp_var.clone, node_cond)
        end
      end

      a_if = nil
      final_if = nil
      node.whens.each do |wh|
        final_comp = nil
        wh.conds.each do |cond|
          if temp_var
            right_side = temp_var.clone
            if cond.is_a?(NilLiteral)
              comp = IsA.new(right_side, Path.global("Nil"))
            elsif cond.is_a?(Path) || cond.is_a?(Generic)
              comp = IsA.new(right_side, cond)
            elsif cond.is_a?(Call) && cond.obj.is_a?(ImplicitObj)
              implicit_call = cond.clone as Call
              implicit_call.obj = temp_var.clone
              comp = implicit_call
            else
              comp = Call.new(cond, "===", right_side)
            end
          else
            comp = cond
          end

          comp.location = cond.location

          if final_comp
            final_comp = Or.new(final_comp, comp)
          else
            final_comp = comp
          end
        end

        wh_if = If.new(final_comp.not_nil!, wh.body)
        if a_if
          a_if.else = wh_if
        else
          final_if = wh_if
        end
        a_if = wh_if
      end

      if node_else = node.else
        a_if.not_nil!.else = node_else
      end

      final_if = final_if.not_nil!
      final_exp = if assign
                    Expressions.new([assign, final_if] of ASTNode)
                  else
                    final_if
                  end
      final_exp.location = node.location
      final_exp
    end

    private def regex_new_call(node, value)
      Call.new(Path.global("Regex").at(node), "new", value, regex_options(node)).at(node)
    end

    private def regex_options(node)
      Call.new(Path.global(["Regex", "Options"]).at(node), "new", NumberLiteral.new(node.options.value).at(node)).at(node)
    end

    def expand(node)
      raise "#{node} (#{node.class}) can't be expanded"
    end

    def new_temp_var
      @program.new_temp_var
    end
  end
end
