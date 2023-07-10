module Crystal
  class LiteralExpander
    def initialize(@program : Program)
      @regexes = [] of {String, Regex::CompileOptions}
    end

    # Converts an array literal to creating an Array and storing the values:
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
    #     ary = ::Array(typeof(1, 2, 3)).unsafe_build(3)
    #     buf = ary.to_unsafe
    #     buf[0] = 1
    #     buf[1] = 2
    #     buf[2] = 3
    #     ary
    #
    # From:
    #
    #     [1, *exp2, *exp3, 4]
    #
    # To:
    #
    #     temp1 = exp2
    #     temp2 = exp3
    #     ary = ::Array(typeof(1, ::Enumerable.element_type(temp1), ::Enumerable.element_type(temp2), 4)).new(2)
    #     ary << 1
    #     ary.concat(temp1)
    #     ary.concat(temp2)
    #     ary << 4
    #     ary
    def expand(node : ArrayLiteral)
      elem_temp_vars, elem_temp_var_count = complex_elem_temp_vars(node.elements)
      if node_of = node.of
        type_var = node_of
      else
        type_var = typeof_exp(node, elem_temp_vars)
      end

      capacity = node.elements.count { |elem| !elem.is_a?(Splat) }

      generic = Generic.new(Path.global("Array"), type_var).at(node)

      if node.elements.any?(Splat)
        ary_var = new_temp_var.at(node)

        ary_instance = Call.new(generic, "new", NumberLiteral.new(capacity).at(node)).at(node)

        exps = Array(ASTNode).new(node.elements.size + elem_temp_var_count + 2)
        elem_temp_vars.try &.each_with_index do |elem_temp_var, i|
          next unless elem_temp_var
          elem_exp = node.elements[i]
          elem_exp = elem_exp.exp if elem_exp.is_a?(Splat)
          exps << Assign.new(elem_temp_var, elem_exp.clone).at(elem_temp_var)
        end
        exps << Assign.new(ary_var.clone, ary_instance).at(node)

        node.elements.each_with_index do |elem, i|
          temp_var = elem_temp_vars.try &.[i]
          if elem.is_a?(Splat)
            exps << Call.new(ary_var.clone, "concat", (temp_var || elem.exp).clone).at(node)
          else
            exps << Call.new(ary_var.clone, "<<", (temp_var || elem).clone).at(node)
          end
        end

        exps << ary_var

        Expressions.new(exps).at(node)
      elsif capacity.zero?
        Call.new(generic, "new").at(node)
      else
        ary_var = new_temp_var.at(node)

        ary_instance = Call.new(generic, "unsafe_build", NumberLiteral.new(capacity).at(node)).at(node)

        buffer = Call.new(ary_var, "to_unsafe").at(node)
        buffer_var = new_temp_var.at(node)

        exps = Array(ASTNode).new(node.elements.size + elem_temp_var_count + 3)
        elem_temp_vars.try &.each_with_index do |elem_temp_var, i|
          next unless elem_temp_var
          elem_exp = node.elements[i]
          exps << Assign.new(elem_temp_var, elem_exp.clone).at(elem_temp_var)
        end
        exps << Assign.new(ary_var.clone, ary_instance).at(node)
        exps << Assign.new(buffer_var, buffer).at(node)

        node.elements.each_with_index do |elem, i|
          temp_var = elem_temp_vars.try &.[i]
          exps << Call.new(buffer_var.clone, "[]=", NumberLiteral.new(i).at(node), (temp_var || elem).clone).at(node)
        end

        exps << ary_var.clone

        Expressions.new(exps).at(node)
      end
    end

    def complex_elem_temp_vars(elems : Array, &)
      temp_vars = nil
      count = 0

      elems.each_with_index do |elem, i|
        elem = yield elem
        elem = elem.exp if elem.is_a?(Splat)
        next if elem.is_a?(Var) || elem.is_a?(InstanceVar) || elem.is_a?(ClassVar) || elem.simple_literal?

        temp_vars ||= Array(Var?).new(elems.size, nil)
        temp_vars[i] = new_temp_var.at(elem)
        count += 1
      end

      {temp_vars, count}
    end

    def complex_elem_temp_vars(elems : Array(ASTNode))
      complex_elem_temp_vars(elems, &.itself)
    end

    def typeof_exp(node : ArrayLiteral, temp_vars : Array(Var?)? = nil)
      type_exps = node.elements.map_with_index do |elem, i|
        temp_var = temp_vars.try &.[i]
        if elem.is_a?(Splat)
          Call.new(Path.global("Enumerable").at(node), "element_type", (temp_var || elem.exp).clone).at(node)
        else
          (temp_var || elem).clone
        end
      end

      TypeOf.new(type_exps).at(node)
    end

    # Converts an array-like literal to creating a container and storing the values:
    #
    # From:
    #
    #     T{1, 2, 3}
    #
    # To:
    #
    #     ary = T.new
    #     ary << 1
    #     ary << 2
    #     ary << 3
    #     ary
    #
    # From:
    #
    #     T{1, *exp2, *exp3, 4}
    #
    # To:
    #
    #     ary = T.new
    #     ary << 1
    #     exp2.each { |v| ary << v }
    #     exp3.each { |v| ary << v }
    #     ary << 4
    #     ary
    #
    # If `T` is an uninstantiated generic type, injects a `typeof` with the
    # element types.
    def expand_named(node : ArrayLiteral, generic_type : ASTNode?)
      elem_temp_vars, elem_temp_var_count = complex_elem_temp_vars(node.elements)
      if generic_type
        type_of = typeof_exp(node, elem_temp_vars)
        node_name = Generic.new(generic_type, type_of).at(node)
      else
        node_name = node.name
      end

      constructor = Call.new(node_name, "new").at(node)
      if node.elements.empty?
        return constructor
      end

      ary_var = new_temp_var.at(node)

      exps = Array(ASTNode).new(node.elements.size + elem_temp_var_count + 2)
      elem_temp_vars.try &.each_with_index do |elem_temp_var, i|
        next unless elem_temp_var
        elem_exp = node.elements[i]
        elem_exp = elem_exp.exp if elem_exp.is_a?(Splat)
        exps << Assign.new(elem_temp_var, elem_exp.clone).at(elem_temp_var)
      end
      exps << Assign.new(ary_var.clone, constructor).at(node)

      node.elements.each_with_index do |elem, i|
        temp_var = elem_temp_vars.try &.[i]
        if elem.is_a?(Splat)
          yield_var = new_temp_var
          each_body = Call.new(ary_var.clone, "<<", yield_var.clone).at(node)
          each_block = Block.new(args: [yield_var], body: each_body).at(node)
          exps << Call.new((temp_var || elem.exp).clone, "each", block: each_block).at(node)
        else
          exps << Call.new(ary_var.clone, "<<", (temp_var || elem).clone).at(node)
        end
      end

      exps << ary_var

      Expressions.new(exps).at(node)
    end

    # Converts a hash literal into creating a Hash and assigning keys and values.
    #
    # Equivalent to a hash-like literal using `::Hash`.
    def expand(node : HashLiteral)
      expand_named(node, Path.global("Hash"))
    end

    # Converts a hash-like literal into creating a Hash and assigning keys and values:
    #
    # From:
    #
    #     T{}
    #
    # To:
    #
    #     T.new
    #
    # From:
    #
    #     {} of K => V
    #
    # To:
    #
    #     ::Hash(K, V).new
    #
    # From:
    #
    #     T{a => b, c => d}
    #
    # To:
    #
    #     hash = T.new
    #     hash[a] = b
    #     hash[c] = d
    #     hash
    #
    # Or if `T` is an uninstantiated generic type:
    #
    #     hash = T(typeof(a, c), typeof(b, d)).new
    #     hash[a] = b
    #     hash[c] = d
    #     hash
    def expand_named(node : HashLiteral, generic_type : ASTNode?)
      key_temp_vars, key_temp_var_count = complex_elem_temp_vars(node.entries, &.key)
      value_temp_vars, value_temp_var_count = complex_elem_temp_vars(node.entries, &.value)

      if of = node.of
        # `generic_type` is nil here
        type_vars = [of.key, of.value] of ASTNode
        generic = Generic.new(Path.global("Hash"), type_vars).at(node)
      elsif generic_type
        # `node.entries` is non-empty here
        typeof_key = TypeOf.new(node.entries.map_with_index { |x, i| (key_temp_vars.try(&.[i]) || x.key).clone.as(ASTNode) }).at(node)
        typeof_value = TypeOf.new(node.entries.map_with_index { |x, i| (value_temp_vars.try(&.[i]) || x.value).clone.as(ASTNode) }).at(node)
        generic = Generic.new(generic_type, [typeof_key, typeof_value] of ASTNode).at(node)
      else
        generic = node.name
      end

      constructor = Call.new(generic, "new").at(node)
      return constructor if node.entries.empty?

      hash_var = new_temp_var

      exps = Array(ASTNode).new(node.entries.size + key_temp_var_count + value_temp_var_count + 2)
      key_temp_vars.try &.each_with_index do |key_temp_var, i|
        next unless key_temp_var
        key_exp = node.entries[i].key
        exps << Assign.new(key_temp_var, key_exp.clone).at(key_temp_var)
      end
      value_temp_vars.try &.each_with_index do |value_temp_var, i|
        next unless value_temp_var
        value_exp = node.entries[i].value
        exps << Assign.new(value_temp_var, value_exp.clone).at(value_temp_var)
      end
      exps << Assign.new(hash_var.clone, constructor).at(node)

      node.entries.each_with_index do |entry, i|
        key_exp = key_temp_vars.try(&.[i]) || entry.key
        value_exp = value_temp_vars.try(&.[i]) || entry.value
        exps << Call.new(hash_var.clone, "[]=", key_exp.clone, value_exp.clone).at(node)
      end

      exps << hash_var
      Expressions.new(exps).at(node)
    end

    # From:
    #
    #     /regex/flags
    #
    # To declaring a constant with this value (if not already declared):
    #
    # ```
    # Regex.new("regex", Regex::Options.new(flags))
    # ```
    #
    # and then reading from that constant.
    # That is, we cache regex literals to avoid recompiling them all of the time.
    #
    # Only do this for regex literals that don't contain interpolation.
    # If there's an interpolation, expand to: Regex.new(interpolation, flags)
    def expand(node : RegexLiteral)
      node_value = node.value
      case node_value
      when StringLiteral
        string = node_value.value

        key = {string, node.options}
        index = @regexes.index(key) || @regexes.size
        const_name = "$Regex:#{index}"

        if index == @regexes.size
          @regexes << key

          const_value = regex_new_call(node, StringLiteral.new(string).at(node))
          const = Const.new(@program, @program, const_name, const_value)

          @program.types[const_name] = const
        else
          const = @program.types[const_name].as(Const)
        end

        Path.new(const_name).at(const.value)
      else
        regex_new_call(node, node_value)
      end
    end

    private def regex_new_call(node, value)
      Call.new(Path.global("Regex").at(node), "new", value, regex_options(node)).at(node)
    end

    private def regex_options(node)
      Call.new(Path.global(["Regex", "Options"]).at(node), "new", NumberLiteral.new(node.options.value.to_s).at(node)).at(node)
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
      Call.new(path, "new", node.from, node.to, bool).at(node)
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

      if node.exhaustive?
        a_if.not_nil!.else = node.else || Unreachable.new
      elsif node_else = node.else
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

    # Convert a `select` statement into a `case` statement based on `Channel.select`
    #
    # From:
    #
    #     select
    #     when foo then body
    #     when x = bar then x.baz
    #     end
    #
    # To:
    #
    #     %index, %value = ::Channel.select({foo_select_action, bar_select_action})
    #     case %index
    #     when 0
    #       body
    #     when 1
    #       x = value.as(typeof(foo))
    #       x.baz
    #     else
    #       ::raise("BUG: invalid select index")
    #     end
    #
    #
    # If there's an `else` branch, use `Channel.non_blocking_select`.
    #
    # From:
    #
    #     select
    #     when foo then body
    #     else qux
    #     end
    #
    # To:
    #
    #     %index, %value = ::Channel.non_blocking_select({foo_select_action})
    #     case %index
    #     when 0
    #       body
    #     else
    #       qux
    #     end
    #
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
        case_else = Call.new(nil, "raise", StringLiteral.new("BUG: invalid select index"), global: true).at(node)
      end

      call = Call.new(
        channel,
        node.else ? "non_blocking_select" : "select",
        TupleLiteral.new(tuple_values).at(node),
      ).at(node)
      multi = MultiAssign.new(targets, [call] of ASTNode)
      case_cond = Var.new(index_name).at(node)
      a_case = Case.new(case_cond, case_whens, case_else, exhaustive: false).at(node)
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
      splat_index = nil
      splat_underscore = false
      node.targets.each_with_index do |target, i|
        if target.is_a?(Splat)
          raise "BUG: splat assignment already specified" if splat_index
          splat_index = i
          splat_underscore = true if target.exp.is_a?(Underscore)
        end
      end

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
      #
      # If the flag "strict_multi_assign" is present, requires `temp`'s size to
      # match the number of assign targets exactly: (it must respond to `#size`)
      #
      #     temp = [1, 2]
      #     raise ... if temp.size != 2
      #     a = temp[0]
      #     b = temp[1]
      #
      # From:
      #
      #     a, *b, c, d = [1, 2]
      #
      # To:
      #
      #     temp = [1, 2]
      #     raise ... if temp.size < 3
      #     a = temp[0]
      #     b = temp[1..-3]
      #     c = temp[-2]
      #     d = temp[-1]
      #
      # Except any assignments to *_, including the indexing call, are omitted
      # altogether.
      if node.values.size == 1
        value = node.values[0]
        middle_splat = splat_index && (0 < splat_index < node.targets.size - 1)
        raise_on_count_mismatch = @program.has_flag?("strict_multi_assign") || middle_splat

        temp_var = new_temp_var

        # temp = ...
        assigns = Array(ASTNode).new(node.targets.size + (splat_underscore ? 0 : 1) + (raise_on_count_mismatch ? 1 : 0))
        assigns << Assign.new(temp_var.clone, value).at(value)

        # raise ... if temp.size < ...
        if raise_on_count_mismatch
          size_call = Call.new(temp_var.clone, "size").at(value)
          if middle_splat
            size_comp = Call.new(size_call, "<", NumberLiteral.new(node.targets.size - 1)).at(value)
          else
            size_comp = Call.new(size_call, "!=", NumberLiteral.new(node.targets.size)).at(value)
          end
          index_error = Call.new(Path.global("IndexError"), "new", StringLiteral.new("Multiple assignment count mismatch")).at(value)
          raise_call = Call.global("raise", index_error).at(value)
          assigns << If.new(size_comp, raise_call).at(value)
        end

        # ... = temp[...]
        node.targets.each_with_index do |target, i|
          if i == splat_index
            next if splat_underscore
            indexer = RangeLiteral.new(
              NumberLiteral.new(i),
              NumberLiteral.new(i - node.targets.size),
              false,
            ).at(value)
          else
            indexer = NumberLiteral.new(splat_index && i > splat_index ? i - node.targets.size : i)
          end
          call = Call.new(temp_var.clone, "[]", indexer).at(value)
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
        #
        # From:
        #
        #     a, *b, c = d, e, f, g
        #
        # To:
        #
        #     temp1 = d
        #     temp2 = ::Tuple.new(e, f)
        #     temp3 = g
        #     a = temp1
        #     b = temp2
        #     c = temp3
        #
        # Except values assigned to `*_` are evaluated directly where the
        # `Tuple` would normally be constructed, and no assignments to `_` would
        # actually take place.
      else
        if splat_index
          raise "BUG: multiple assignment count mismatch" if node.targets.size - 1 > node.values.size
        else
          raise "BUG: multiple assignment count mismatch" if node.targets.size != node.values.size
        end

        assign_to_count = splat_underscore ? node.values.size : node.targets.size
        assign_from_count = node.targets.size - (splat_underscore ? 1 : 0)
        assign_to_temps = Array(ASTNode).new(assign_to_count)
        assign_from_temps = Array(ASTNode).new(assign_from_count)

        node.targets.each_with_index do |target, i|
          if i == splat_index
            if splat_underscore
              node.values.each(within: i..i - node.targets.size) do |value|
                assign_to_temps << value
              end
              next
            end
            value = Call.new(Path.global("Tuple").at(node), "new", node.values[i..i - node.targets.size])
          else
            value = node.values[splat_index && i > splat_index ? i - node.targets.size : i]
          end

          temp_var = new_temp_var
          assign_to_temps << Assign.new(temp_var.clone, value).at(node)
          assign_from_temps << transform_multi_assign_target(target, temp_var.clone)
        end

        exps = Expressions.new(assign_to_temps.concat(assign_from_temps))
      end
      exps.location = node.location
      exps
    end

    def transform_multi_assign_target(target, value)
      if target.is_a?(Splat)
        target = target.exp
      end

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
            return IsA.new(right_side, Metaclass.new(obj).at(obj))
          end
        when Generic
          if cond.name == "class"
            return IsA.new(right_side, Metaclass.new(obj).at(obj))
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

    # Expand this:
    #
    # ```
    # ->foo.bar(X, Y)
    # ```
    #
    # To this:
    #
    # ```
    # tmp = foo
    # ->(x : X, y : Y) { tmp.bar(x, y) }
    # ```
    #
    # Expand this:
    #
    # ```
    # ->Foo.bar(X, Y)
    # ```
    #
    # To this:
    #
    # ```
    # ->(x : X, y : Y) { Foo.bar(x, y) }
    # ```
    #
    # Expand this:
    #
    # ```
    # ->bar(X, Y)
    # ```
    #
    # To this:
    #
    # ```
    # ->(x : X, y : Y) { bar(x, y) }
    # ```
    #
    # in case the implicit `self` is a class or a virtual class.
    def expand(node : ProcPointer)
      obj = node.obj

      if obj && !obj.is_a?(Path)
        temp_var = new_temp_var.at(obj)
        assign = Assign.new(temp_var, obj)
        obj = temp_var
      end

      def_args = node.args.map do |arg|
        Arg.new(@program.new_temp_var_name, restriction: arg).at(arg)
      end

      call_args = def_args.map do |def_arg|
        Var.new(def_arg.name).at(def_arg).as(ASTNode)
      end

      body = Call.new(obj, node.name, call_args, global: node.global?).at(node)
      proc_literal = ProcLiteral.new(Def.new("->", def_args, body).at(node)).at(node)
      proc_literal.proc_pointer = node

      if assign
        Expressions.new([assign, proc_literal])
      else
        proc_literal
      end
    end

    def expand(node)
      raise "#{node} (#{node.class}) can't be expanded"
    end

    def new_temp_var
      @program.new_temp_var
    end
  end
end
