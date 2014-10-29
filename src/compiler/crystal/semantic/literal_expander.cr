module Crystal
  class LiteralExpander
    def initialize(@program)
      @regexes = [] of {String, Int32}
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
          generic = Generic.new(Path.global("Array"), [node_of] of ASTNode)
          generic.location = node.location

          call = Call.new(generic, "new")
          call.location = node.location
          return call
        end

        type_var = node_of
      else
        type_var = TypeOf.new(node.elements)
      end

      length = node.elements.length
      capacity = length

      generic = Generic.new(Path.global("Array"), [type_var] of ASTNode)
      generic.location = node.location

      constructor = Call.new(generic, "new", [NumberLiteral.new(capacity)] of ASTNode)
      constructor.location = node.location

      temp_var = new_temp_var
      assign = Assign.new(temp_var.clone, constructor)
      assign.location = node.location

      set_length = Call.new(temp_var.clone, "length=", [NumberLiteral.new(length)] of ASTNode)
      set_length.location = node.location

      get_buffer = Call.new(temp_var.clone, "buffer")
      get_buffer.location = node.location

      buffer = new_temp_var
      buffer.location = node.location

      assign_buffer = Assign.new(buffer.clone, get_buffer)
      assign_buffer.location = node.location

      exps = [assign, set_length, assign_buffer] of ASTNode

      node.elements.each_with_index do |elem, i|
        assign_index = Call.new(buffer.clone, "[]=", [NumberLiteral.new(i), elem] of ASTNode)
        assign_index.location = node.location

        exps << assign_index
      end

      exps << temp_var.clone

      exps = Expressions.new(exps)
      exps.location = node.location
      exps
    end

    def expand_named(node : ArrayLiteral)
      temp_var = new_temp_var

      constructor = Call.new(node.name, "new")
      constructor.location = node.location

      if node.elements.empty?
        return constructor
      end

      assign = Assign.new(temp_var.clone, constructor)
      assign.location = node.location

      exps = [assign] of ASTNode

      node.elements.each do |elem|
        push = Call.new(temp_var.clone, "<<", [elem] of ASTNode)
        push.location = node.location
        exps << push
      end

      exps << temp_var.clone

      exps = Expressions.new(exps)
      exps.location = node.location
      exps
    end

    def expand_named(node : HashLiteral)
      constructor = Call.new(node.name, "new")
      constructor.location = node.location

      if node.entries.empty?
        return constructor
      end

      temp_var = new_temp_var

      assign = Assign.new(temp_var.clone, constructor)
      assign.location = node.location

      exps = [assign] of ASTNode
      node.entries.each do |entry|
        call = Call.new(temp_var.clone, "[]=", [entry.key, entry.value])
        call.location = node.location
        exps << call
      end
      exps << temp_var.clone

      exp = Expressions.new exps
      exp.location = node.location
      exp
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
        typeof_key = TypeOf.new(node.entries.map &.key)
        typeof_key.location = node.location

        typeof_value = TypeOf.new(node.entries.map &.value)
        typeof_value.location = node.location

        type_vars = [typeof_key, typeof_value] of ASTNode
      end

      generic = Generic.new(Path.global("Hash"), type_vars)
      generic.location = node.location

      constructor = Call.new(generic, "new")
      constructor.location = node.location

      if node.entries.empty?
        constructor
      else
        temp_var = new_temp_var
        assign = Assign.new(temp_var.clone, constructor)

        exps = [assign] of ASTNode
        node.entries.each do |entry|
          exps << Call.new(temp_var.clone, "[]=", [entry.key, entry.value])
        end
        exps << temp_var.clone
        exp = Expressions.new exps
        exp.location = node.location
        exp
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
    #       $some_global = Regex.new("regex", flags)
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

        key = {string, node.modifiers}
        index = @regexes.index key
        unless index
          index = @regexes.length
          @regexes << key
        end

        global_name = "$Regex:#{index}"
        temp_name = @program.new_temp_var_name
        @program.initialized_global_vars.add global_name
        first_assign = Assign.new(Var.new(temp_name), Global.new(global_name))
        regex = Call.new(Path.global("Regex"), "new", [StringLiteral.new(string), NumberLiteral.new(node.modifiers)] of ASTNode)
        second_assign = Assign.new(Global.new(global_name), regex)
        If.new(first_assign, Var.new(temp_name), second_assign)
      else
        Call.new(Path.global("Regex"), "new", [node_value, NumberLiteral.new(node.modifiers)] of ASTNode)
      end
    end

    def expand(node)
      raise "#{node} can't be expanded"
    end

    def new_temp_var
      @program.new_temp_var
    end
  end
end
