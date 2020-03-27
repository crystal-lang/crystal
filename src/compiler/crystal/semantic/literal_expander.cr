module Crystal
  class LiteralExpander
    def initialize(@program : Program)
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
    #     Array(typeof(1, 2, 3)).new(3) do |buffer|
    #       buffer[0] = 1
    #       buffer[1] = 2
    #       buffer[2] = 3
    #       3
    #     end
    def expand(node : ArrayLiteral)
      if node_of = node.of
        if node.elements.size == 0
          generic = Generic.new(Path.global("Array"), node_of).at(node)
          call = Call.new(generic, "new").at(node)
          return call
        end

        type_var = node_of
      else
        type_var = TypeOf.new(node.elements.clone)
      end

      capacity = node.elements.size

      buffer = new_temp_var.at(node)

      exps = Array(ASTNode).new(node.elements.size + 1)
      node.elements.each_with_index do |elem, i|
        exps << Call.new(buffer.clone, "[]=", NumberLiteral.new(i).at(node), elem.clone).at(node)
      end
      exps << NumberLiteral.new(capacity).at(node)
      block_body = Expressions.new(exps).at(node)

      block = Block.new([buffer.clone], block_body).at(node)

      generic = Generic.new(Path.global("Array"), type_var).at(node)
      Call.new(generic, "build", args: [NumberLiteral.new(capacity).at(node)] of ASTNode, block: block).at(node)
    end

    def expand_named(node : ArrayLiteral)
      temp_var = new_temp_var

      constructor = Call.new(node.name, "new").at(node)

      if node.elements.empty?
        return constructor
      end

      exps = Array(ASTNode).new(node.elements.size + 2)
      exps << Assign.new(temp_var.clone, constructor).at(node)
      node.elements.each do |elem|
        exps << Call.new(temp_var.clone, "<<", elem.clone).at(node)
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

      exps = Array(ASTNode).new(node.entries.size + 2)
      exps << Assign.new(temp_var.clone, constructor).at(node)
      node.entries.each do |entry|
        exps << Call.new(temp_var.clone, "[]=", [entry.key.clone, entry.value.clone] of ASTNode).at(node)
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
        typeof_key = TypeOf.new(node.entries.map { |x| x.key.clone.as(ASTNode) }).at(node)
        typeof_value = TypeOf.new(node.entries.map { |x| x.value.clone.as(ASTNode) }).at(node)
        type_vars = [typeof_key, typeof_value] of ASTNode
      end

      generic = Generic.new(Path.global("Hash"), type_vars).at(node)
      constructor = Call.new(generic, "new").at(node)

      if node.entries.empty?
        constructor
      else
        temp_var = new_temp_var

        exps = Array(ASTNode).new(node.entries.size + 2)
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
          index = @regexes.size
          @regexes << key
        end

        global_name = "$Regex:#{index}"
        temp_name = @program.new_temp_var_name

        global_var = MetaTypeVar.new(global_name)
        global_var.owner = @program
        type = @program.nilable(@program.regex)
        global_var.freeze_type = type
        global_var.type = type

        # TODO: need to bind with nil_var for codegen, but shouldn't be needed
        global_var.bind_to(@program.nil_var)

        @program.global_vars[global_name] = global_var

        first_assign = Assign.new(Var.new(temp_name).at(node), Global.new(global_name).at(node)).at(node)
        regex = regex_new_call(node, StringLiteral.new(string).at(node))
        second_assign = Assign.new(Global.new(global_name).at(node), regex).at(node)
        If.new(first_assign, Var.new(temp_name).at(node), second_assign).at(node)
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
      left = node.left.single_expression

      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
                   If.new(left, node.right, left.clone).at(node)
                 elsif left.is_a?(Assign) && left.target.is_a?(Var)
                   If.new(left, node.right, left.target.clone).at(node)
                 elsif left.is_a?(Not) && left.exp.is_a?(Var)
                   If.new(left, node.right, left.clone).at(node)
                 elsif left.is_a?(Not) && ((left_exp = left.exp).is_a?(IsA) && left_exp.obj.is_a?(Var))
                   If.new(left, node.right, left.clone).at(node)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var.clone, left).at(node), node.right, temp_var.clone).at(node)
                 end
      new_node.and = true
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
      left = node.left.single_expression

      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
                   If.new(left, left.clone, node.right).at(node)
                 elsif left.is_a?(Assign) && left.target.is_a?(Var)
                   If.new(left, left.target.clone, node.right).at(node)
                 elsif left.is_a?(Not) && left.exp.is_a?(Var)
                   If.new(left, left.clone, node.right).at(node)
                 elsif left.is_a?(Not) && ((left_exp = left.exp).is_a?(IsA) && left_exp.obj.is_a?(Var))
                   If.new(left, left.clone, node.right).at(node)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var.clone, left).at(node), temp_var.clone, node.right).at(node)
                 end
      new_node.or = true
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
      bool = BoolLiteral.new(node.exclusive?).at(node)
      Call.new(path, "new", [node.from, node.to, bool]).at(node)
    end

    # Convert an interpolation to a call to `String.interpolation`
    #
    # From:
    #
    #     "foo#{bar}baz#{qux}"
    #
    # To:
    #
    #     String.interpolation("foo", bar, "baz", qux)
    def expand(node : StringInterpolation)
      # We could do `node.expressions.dup` for more purity,
      # but the string interpolation isn't used later on so this is fine,
      # and having pieces in a different representation but same end
      # result is just fine.
      pieces = node.expressions
      combine_contiguous_string_literals(pieces)
      Call.new(Path.global("String").at(node), "interpolation", pieces).at(node)
    end

    private def combine_contiguous_string_literals(pieces)
      i = 0
      pieces.reject! do |piece|
        delete =
          if i < pieces.size - 1
            next_piece = pieces[i + 1]
            if piece.is_a?(StringLiteral) && next_piece.is_a?(StringLiteral)
              pieces[i + 1] = StringLiteral.new(piece.value + next_piece.value)
              true
            else
              false
            end
          else
            false
          end
        i += 1
        delete
      end
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
    #
    # We also take care to expand multiple conds
    #
    # From:
    #
    #     case {x, y}
    #     when {1, 2}, {3, 4}
    #       3
    #     end
    #
    # To:
    #
    #     if (1 === x && y === 2) || (3 === x && 4 === y)
    #       3
    #     end
    def expand(node : Case)
      node_cond = node.cond

      if node.whens.empty?
        expressions = [] of ASTNode

        node_else = node.else
        if node_cond
          expressions << node_cond
          expressions << NilLiteral.new unless node_else
        end
        if node_else
          expressions << node_else
        end

        return Expressions.new(expressions).at(node)
      end

      if node_cond
        if node_cond.is_a?(TupleLiteral)
          conds = node_cond.elements
        else
          conds = [node_cond]
        end

        assigns = [] of ASTNode
        temp_vars = conds.map do |cond|
          case cond = cond.single_expression
          when Var, InstanceVar
            temp_var = cond
          when Assign
            temp_var = cond.target
            assigns << cond
          else
            temp_var = new_temp_var
            assigns << Assign.new(temp_var.clone, cond).at(node_cond)
          end
          temp_var
        end
      end

      a_if = nil
      final_if = nil
      node.whens.each do |wh|
        final_comp = nil
        wh.conds.each do |cond|
          next if cond.is_a?(Underscore)

          if node_cond.is_a?(TupleLiteral)
            if cond.is_a?(TupleLiteral)
              comp = nil
              cond.elements.zip(temp_vars.not_nil!) do |lh, rh|
                next if lh.is_a?(Underscore)

                sub_comp = case_when_comparison(rh, lh).at(cond)
                if comp
                  comp = And.new(comp, sub_comp).at(comp)
                else
                  comp = sub_comp
                end
              end
            else
              comp = case_when_comparison(TupleLiteral.new(temp_vars.not_nil!.clone), cond).at(cond)
            end
          else
            temp_var = temp_vars.try &.first
            comp = case_when_comparison(temp_var, cond).at(cond)
          end

          next unless comp

          if final_comp
            final_comp = Or.new(final_comp, comp).at(final_comp)
          else
            final_comp = comp
          end
        end

        final_comp ||= BoolLiteral.new(true)

        wh_if = If.new(final_comp, wh.body).at(final_comp)
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
      final_exp = if assigns && !assigns.empty?
                    assigns << final_if
                    Expressions.new(assigns).at(node)
                  else
                    final_if
                  end
      final_exp.location = node.location
      final_exp
    end

    def expand(node : Select)
      index_name = @program.new_temp_var_name
      value_name = @program.new_temp_var_name

      targets = [Var.new(index_name).at(node), Var.new(value_name).at(node)] of ASTNode
      channel = Path.global("Channel").at(node)

      tuple_values = [] of ASTNode
      case_whens = [] of When

      node.whens.each_with_index do |a_when, index|
        condition = a_when.condition
        case condition
        when Call
          cloned_call = condition.clone
          cloned_call.name = select_action_name(cloned_call.name)
          tuple_values << cloned_call

          case_whens << When.new([NumberLiteral.new(index).at(node)] of ASTNode, a_when.body.clone)
        when Assign
          cloned_call = condition.value.as(Call).clone
          cloned_call.name = select_action_name(cloned_call.name)
          tuple_values << cloned_call

          typeof_node = TypeOf.new([condition.value.clone] of ASTNode).at(node)
          cast = Cast.new(Var.new(value_name).at(node), typeof_node).at(node)
          new_assign = Assign.new(condition.target.clone, cast).at(node)
          new_body = Expressions.new([new_assign, a_when.body.clone] of ASTNode)
          case_whens << When.new([NumberLiteral.new(index).at(node)] of ASTNode, new_body)
        else
          node.raise "BUG: expected select when expression to be Assign or Call, not #{condition}"
        end
      end

      if node_else = node.else
        case_else = node_else.clone
      else
        case_else = Call.new(nil, "raise", args: [StringLiteral.new("BUG: invalid select index")] of ASTNode, global: true).at(node)
      end

      call_name = node.else ? "non_blocking_select" : "select"
      call_args = [TupleLiteral.new(tuple_values).at(node)] of ASTNode

      call = Call.new(channel, call_name, call_args).at(node)
      multi = MultiAssign.new(targets, [call] of ASTNode)
      case_cond = Var.new(index_name).at(node)
      a_case = Case.new(case_cond, case_whens, case_else).at(node)
      Expressions.from([multi, a_case] of ASTNode).at(node)
    end

    def select_action_name(name)
      case name
      when .ends_with? "!"
        name[0...-1] + "_select_action!"
      when .ends_with? "?"
        name[0...-1] + "_select_action?"
      else
        name + "_select_action"
      end
    end

    # Transform a multi assign into many assigns.
    def expand(node : MultiAssign)
      # From:
      #
      #     a, b = [1, 2]
      #
      #
      # To:
      #
      #     temp = [1, 2]
      #     a = temp[0]
      #     b = temp[1]
      if node.values.size == 1
        value = node.values[0]

        temp_var = new_temp_var

        assigns = Array(ASTNode).new(node.targets.size + 1)
        assigns << Assign.new(temp_var.clone, value).at(value)
        node.targets.each_with_index do |target, i|
          call = Call.new(temp_var.clone, "[]", NumberLiteral.new(i)).at(value)
          assigns << transform_multi_assign_target(target, call)
        end
        exps = Expressions.new(assigns)

        # From:
        #
        #     a, b = c, d
        #
        # To:
        #
        #     temp1 = c
        #     temp2 = d
        #     a = temp1
        #     b = temp2
      else
        raise "BUG: multiple assignment count mismatch" unless node.targets.size == node.values.size

        temp_vars = node.values.map { new_temp_var }

        assign_to_temps = [] of ASTNode
        assign_from_temps = [] of ASTNode

        temp_vars.each_with_index do |temp_var_2, i|
          target = node.targets[i]
          value = node.values[i]
          if target.is_a?(Path)
            assign_from_temps << Assign.new(target, value).at(node)
          else
            assign_to_temps << Assign.new(temp_var_2.clone, value).at(node)
            assign_from_temps << transform_multi_assign_target(target, temp_var_2.clone)
          end
        end

        exps = Expressions.new(assign_to_temps + assign_from_temps)
      end
      exps.location = node.location
      exps
    end

    def transform_multi_assign_target(target, value)
      if target.is_a?(Call)
        target.name = "#{target.name}="
        target.args << value
        target
      else
        Assign.new(target, value).at(target)
      end
    end

    private def case_when_comparison(temp_var, cond)
      return cond unless temp_var

      right_side = temp_var.clone

      check_implicit_obj Call
      check_implicit_obj RespondsTo
      check_implicit_obj IsA
      check_implicit_obj Cast
      check_implicit_obj NilableCast
      check_implicit_obj Not

      case cond
      when NilLiteral
        return IsA.new(right_side, Path.global("Nil"))
      when Path, Generic
        return IsA.new(right_side, cond)
      when Call
        obj = cond.obj
        case obj
        when Path
          if cond.name == "class"
            return IsA.new(right_side, Metaclass.new(obj.clone).at(obj))
          end
        when Generic
          if cond.name == "class"
            return IsA.new(right_side, Metaclass.new(obj.clone).at(obj))
          end
        else
          # no special treatment
        end
      else
        # no special treatment
      end

      Call.new(cond, "===", right_side)
    end

    macro check_implicit_obj(type)
      if cond.is_a?({{type}})
        cond_obj = cond.is_a?(Not) ? cond.exp : cond.obj
        if cond_obj.is_a?(ImplicitObj)
          implicit_call = cond.clone.as({{type}})
          if implicit_call.is_a?(Not)
            implicit_call.exp = temp_var.clone
          else
            implicit_call.obj = temp_var.clone
          end
          return implicit_call
        end
      end
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
