require "program"
require "transformer"
require "set"

module Crystal
  class Program
    def normalize(node)
      normalizer = Normalizer.new(self)
      node = normalizer.normalize(node)
      puts node if ENV["SSA"] == "1"
      node
    end
  end

  class Normalizer < Transformer
    class Index
      getter read
      getter write
      getter frozen

      def initialize(@read = 0, @write = 1, @frozen = false)
      end

      def increment
        Index.new(@write, @write + 1, @frozen)
      end

      def freeze
        @frozen = true
      end

      def ==(other : self)
        @read == other.read && @write == other.write && @frozen == other.frozen
      end

      def to_s
        "(read: #{@read}, write: #{@write}, frozen: #{@frozen})"
      end
    end

    getter program

    def initialize(@program)
      @vars = {} of String => Index
      @vars_stack = [] of Hash(String, Index)
      @in_initialize = false
      @in_def = false
      @dead_code = false
      @exception_handler_count = 0
    end

    def normalize(node)
      node.transform(self)
    end

    def before_transform(node)
      @dead_code = false
    end

    def after_transform(node)
      case node
      when Return, Break, Next
        @dead_code = true
      when If, Case, Unless, And, Or, Expressions, Block
      when While
        reset_instance_variables_indices
        @dead_code = false
      else
        @dead_code = false
      end
    end

    def reset_instance_variables_indices
      return if @in_initialize

      @vars.each do |key, value|
        if key[0] == '@'
          @vars[key] = Index.new(nil, value.write)
        end
      end
    end

    def transform(node : Expressions)
      exps = [] of ASTNode
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end
        end
        break if @dead_code
      end
      case exps.length
      when 0
        Nop.new
      when 1
        exps[0]
      else
        node.expressions = exps
        node
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
    def transform(node : And)
      left = node.left.transform(self)
      right = node.right.transform(self)
      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
               If.new(left, right, left.clone)
             else
               temp_var = new_temp_var
               If.new(Assign.new(temp_var, left), right, temp_var)
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
    def transform(node : Or)
      left = node.left
      new_node = if left.is_a?(Var)
                   If.new(left, left.clone, node.right)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var, left), temp_var, node.right)
                 end
      new_node.binary = :or
      new_node.location = node.location
      new_node.transform(self)
    end

    # Store regex in a constant and replace the regex by this constant
    # (so we don't create an object each time).
    #
    # From:
    #
    #     /regex/
    #
    # To:
    #
    #     ::CONST = /regex/
    #     CONST
    def transform(node : RegexLiteral)
      const_name = "#Regex_#{node.value}_#{node.modifiers}"
      unless program.types[const_name]?
        constructor = Call.new(Path.new(["Regex"], true), "new", [StringLiteral.new(node.value), NumberLiteral.new(node.modifiers, :i32)] of ASTNode)
        program.types[const_name] = const = Const.new program, program, const_name, constructor, [program] of Type, program
        @program.regexes << const
      end

      Path.new([const_name], true)
    end

    # Convert an interpolation to a concatenation with a StringBuilder:
    #
    # From:
    #
    #     "foo#{bar}baz"
    #
    # To:
    #
    #     (StringBuilder.new << "foo" << bar << "baz").to_s
    def transform(node : StringInterpolation)
      super

      call = Call.new(Path.new(["StringBuilder"], true), "new")
      node.expressions.each do |piece|
        call = Call.new(call, "<<", [piece])
      end
      Call.new(call, "to_s")
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
    def transform(node : RangeLiteral)
      super

      Call.new(Path.new(["Range"], true), "new", [node.from, node.to, BoolLiteral.new(node.exclusive)])
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
    def transform(node : ArrayLiteral)
      super

      if node_of = node.of
        if node.elements.length == 0
          generic = NewGenericClass.new(Path.new(["Array"], true), [node_of] of ASTNode)
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

      generic = NewGenericClass.new(Path.new(["Array"], true), [type_var] of ASTNode)
      generic.location = node.location

      constructor = Call.new(generic, "new", [NumberLiteral.new(capacity, :i32)] of ASTNode)
      constructor.location = node.location

      temp_var = new_temp_var
      assign = Assign.new(temp_var, constructor)
      assign.location = node.location

      set_length = Call.new(temp_var, "length=", [NumberLiteral.new(length, :i32)] of ASTNode)
      set_length.location = node.location

      get_buffer = Call.new(temp_var, "buffer")
      get_buffer.location = node.location

      buffer = new_temp_var
      buffer.location = node.location

      assign_buffer = Assign.new(buffer, get_buffer)
      assign_buffer.location = node.location

      exps = [assign, set_length, assign_buffer] of ASTNode

      node.elements.each_with_index do |elem, i|
        assign_index = Call.new(buffer, "[]=", [NumberLiteral.new(i, :i32), elem] of ASTNode)
        assign_index.location = node.location

        exps << assign_index
      end

      exps << temp_var

      exps = Expressions.new(exps)
      exps.location = node.location
      exps
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
    def transform(node : HashLiteral)
      super

      if (node_of_key = node.of_key)
        node_of_value = node.of_value
        raise "Bug: node.of_value shouldn't be nil if node.of_key is not nil" unless node_of_value

        type_vars = [node_of_key, node_of_value] of ASTNode
      else
        type_vars = [TypeOf.new(node.keys), TypeOf.new(node.values)] of ASTNode
      end

      constructor = Call.new(NewGenericClass.new(Path.new(["Hash"], true), type_vars), "new")
      if node.keys.length == 0
        constructor
      else
        temp_var = new_temp_var
        assign = Assign.new(temp_var, constructor)

        exps = [assign] of ASTNode
        node.keys.each_with_index do |key, i|
          exps << Call.new(temp_var, "[]=", [key, node.values[i]])
        end
        exps << temp_var
        Expressions.new exps
      end
    end

    def transform(node : Assign)
      target = node.target
      case target
      when Var
        node.value = node.value.transform(self)
        transform_assign_var(target)
      when Path
        pushing_vars do
          node.value = node.value.transform(self)
        end
      when InstanceVar
        node.value = node.value.transform(self)
        if @in_def
          transform_assign_ivar(node, target)
        end
      else
        node.value = node.value.transform(self)
      end

      node
    end

    def transform_assign_var(node)
      indices = @vars[node.name]?
      if indices
        if indices.frozen || @in_initialize || @exception_handler_count > 0
          node.name = var_name_with_index(node.name, indices.read)
        else
          increment_var node.name, indices
          node.name = var_name_with_index(node.name, indices.write)
        end
      else
        @vars[node.name] = Index.new
      end
    end

    def transform_assign_ivar(node, target)
      indices = @vars[target.name]?
      if indices
        indices = increment_var target.name, indices
      else
        indices = @vars[target.name] = Index.new(1, 2)
      end

      return if @in_initialize

      ivar_name = var_name_with_index(target.name, indices.read)
      node.value = Assign.new(Var.new(ivar_name), node.value)
    end

    def transform(node : DeclareVar)
      var = node.var
      if var.is_a?(Var)
        @vars[var.name] = Index.new
        node
      else
        node
      end
    end

    def transform(node : ExceptionHandler)
      @exception_handler_count += 1

      node = super

      @exception_handler_count -= 1

      node
    end

    # Transform a multi assign into many assigns.
    def transform(node : MultiAssign)
      # From:
      #
      #     a, b = 1
      #
      #
      # To:
      #
      #     temp = 1
      #     a = temp
      #     b = temp
      if node.values.length == 1
        value = node.values[0]

        temp_var = new_temp_var

        assigns = [] of ASTNode

        assign = Assign.new(temp_var, value)
        assign.location = value.location
        assigns << assign

        node.targets.each_with_index do |target, i|
          call = Call.new(temp_var, "[]", [NumberLiteral.new(i, :i32)] of ASTNode)
          call.location = value.location
          assigns << transform_multi_assign_target(target, call)
        end
        exps = Expressions.new(assigns)

      # From:
      #
      #     a = 1, 2, 3
      #
      # To:
      #
      #     a = [1, 2, 3]
      elsif node.targets.length == 1
        target = node.targets.first
        array = ArrayLiteral.new(node.values)
        exps = transform_multi_assign_target(target, array)

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
        temp_vars = node.values.map { new_temp_var }

        assign_to_temps = [] of ASTNode
        assign_from_temps = [] of ASTNode

        temp_vars.each_with_index do |temp_var_2, i|
          assign = Assign.new(temp_var_2, node.values[i])
          assign.location = node.location
          assign_to_temps << assign
          assign_from_temps << transform_multi_assign_target(node.targets[i], temp_var_2)
        end

        exps = Expressions.new(assign_to_temps + assign_from_temps)
      end
      exps.location = node.location
      exps.transform(self)
    end

    def transform_multi_assign_target(target, value)
      if target.is_a?(Call)
        target.name = "#{target.name}="
        target.args << value
        target
      else
        assign = Assign.new(target, value)
        assign.location = target.location
        assign
      end
    end

    def transform(node : Var)
      return node if node.name == "self" || node.name.starts_with?('#')

      if node.out
        @vars[node.name] = Index.new
        return node
      end

      indices = @vars[node.name]?
      node.name = var_name_with_index(node.name, indices ? indices.read : nil)
      node
    end

    def transform(node : InstanceVar)
      return node if !@in_def || @in_initialize

      indices = @vars[node.name]?
      if indices && indices.read
        new_var = var_with_index(node.name, indices.read)
        new_var.location = node.location
        new_var
      else
        if @in_initialize
          node
        else
          if indices
            read_index = indices.write
          else
            read_index = 1
          end
          @vars[node.name] = Index.new(read_index, read_index + 1)
          new_var = var_with_index(node.name, read_index)
          new_var.location = node.location
          assign = Assign.new(new_var, node)
          assign.location = node.location
          assign
        end
      end
    end

    def transform(node : PointerOf)
      exp = node.exp

      if exp.is_a?(Var)
        name = exp.name
        indices = @vars[name]?

        node.exp = exp.transform(self)

        if indices
          indices.freeze
        else
          @vars[name] = Index.new(0, 1, true)
        end
      end

      node
    end

    def transform(node : Yield)
      super.tap do
        reset_instance_variables_indices
      end
    end

    def transform(node : Call)
      # Convert 'a <= b <= c' to 'a <= b && b <= c'
      if comparison?(node.name) && (obj = node.obj) && obj.is_a?(Call) && comparison?(obj.name)
        middle = obj.args.first
        case middle
        when NumberLiteral, Var, InstanceVar
          transform_many node.args
          left = obj
          right = Call.new(middle, node.name, node.args)
        else
          temp_var = new_temp_var
          temp_assign = Assign.new(temp_var, middle)
          left = Call.new(obj.obj, obj.name, [temp_assign] of ASTNode)
          right = Call.new(temp_var, node.name, node.args)
        end
        node = And.new(left, right)
        node = node.transform self
      else
        node = transform_call_and_block(node)
      end

      reset_instance_variables_indices

      node
    end

    def transform_call_and_block(call)
      if call_obj = call.obj
        call.obj = call_obj.transform(self)
      end

      transform_many call.args

      if call_block_arg = call.block_arg
        call.block_arg = call_block_arg.transform(self)
      end

      if block = call.block
        if @in_initialize || @exception_handler_count > 0
          call.block = block.transform(self)
        else
          before_vars = @vars.clone

          block.args.each do |arg|
            @vars[arg.name] = Index.new
          end

          vars_declared_in_body = [] of String

          call.block = block = block.transform(self)

          @vars.each do |name, indices|
            before_indices = before_vars[name]?
            if before_indices && !before_indices.read
              vars_declared_in_body << name
            end
          end

          block.args.each do |arg|
            @vars.delete arg.name
          end

          after_body_vars = get_loop_vars(before_vars)

          vars_declared_in_body.each do |var_name|
            indices = @vars[var_name]
            after_body_vars << assign_var_with_indices(var_name, indices.write, indices.read)
          end

          block.body = append_before_exits(block.body, before_vars, after_body_vars) if block.body && after_body_vars.length > 0

          unless @dead_code
            block.body = concat_preserving_return_value(block.body, after_body_vars)

            if vars_declared_in_body.length > 0
              exps = [] of ASTNode
              vars_declared_in_body.each do |var_name|
                indices = @vars[var_name]
                exps << assign_var_with_indices(var_name, indices.write, nil)
                increment_var(var_name, indices)
              end
              exps << call
              call = Expressions.new(exps)
            end
          end

          # Delete vars declared inside the block
          block_vars = @vars.keys - before_vars.keys
          block_vars.each do |block_var|
            @vars.delete block_var
          end
        end
      end

      call
    end


    def comparison?(name)
      case name
      when "<=", "<", "!=", "==", "===", ">", ">="
        true
      else
        false
      end
    end

    def transform(node : Def)
      # Expand a def with default arguments into many defs:
      #
      # From:
      #
      #   def foo(x, y = 1, z = 2)
      #     ...
      #   end
      #
      # To:
      #
      #   def foo(x)
      #     foo(x, 1)
      #   end
      #
      #   def foo(x, y)
      #     foo(x, y, 2)
      #   end
      #
      #   def foo(x, y, z)
      #     ...
      #   end
      if node.has_default_arguments?
        exps = [] of ASTNode
        node.expand_default_arguments.each do |exp|
          exps << exp.transform(self)
        end
        return Expressions.new(exps)
      end

      if node.body
        if node.uses_block_arg
          block_arg = node.block_arg.not_nil!
          if inputs = block_arg.fun.inputs
            args = inputs.map_with_index { |input, i| Arg.new("#arg#{i}", nil, input) }
            yield_args = [] of ASTNode
            args.each { |arg| yield_args << Var.new(arg.name) }

            body = Yield.new(yield_args)
          else
            args = [] of Arg
            body = Yield.new
          end
          block_def = FunLiteral.new(Def.new("->", args, body))
          assign = Assign.new(Var.new(block_arg.name), block_def)

          node_body = node.body
          if node_body.is_a?(Expressions)
            node_body.expressions.unshift(assign)
          else
            node.body = Expressions.new([assign, node_body] of ASTNode)
          end
        end

        pushing_vars_from_args(node.args) do
          @in_initialize = node.name == "initialize"
          @in_def = true
          node.body = node.body.transform(self)
          @in_def = false
          @in_initialize = false
        end
      end

      node
    end

    def transform(node : FunDef)
      if body = node.body
        pushing_vars_from_args(node.args) do
          @in_def = true
          node.body = body.transform(self)
          @in_def = false
        end
      end

      node
    end

    def transform(node : FunLiteral)
      pushing_vars do
        node.def.body = node.def.body.transform(self)
      end
      node
    end

    def transform(node : Macro)
      node
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
    def transform(node : Case)
      node.cond = node.cond.transform(self)

      if node.cond.is_a?(Var) || node.cond.is_a?(InstanceVar)
        temp_var = node.cond
      else
        temp_var = new_temp_var
        assign = Assign.new(temp_var, node.cond)
      end

      a_if = nil
      final_if = nil
      node.whens.each do |wh|
        final_comp = nil
        wh.conds.each do |cond|
          right_side = temp_var

          if cond.is_a?(Path)
            comp = IsA.new(right_side, cond)
          elsif cond.is_a?(Call) && cond.obj.is_a?(ImplicitObj)
            implicit_call = cond.clone as Call
            implicit_call.obj = temp_var
            comp = implicit_call
          else
            comp = Call.new(cond, "===", [right_side] of ASTNode)
          end
          if final_comp
            final_comp = SimpleOr.new(final_comp, comp)
          else
            final_comp = comp
          end
        end

        raise "Bug: final_comp shouldn't be nil" unless final_comp
        wh_if = If.new(final_comp, wh.body)
        if a_if
          a_if.else = wh_if
        else
          final_if = wh_if
        end
        a_if = wh_if
      end

      raise "Bug: a_if shouldn't be nil" unless a_if

      if node_else = node.else
        a_if.else = node_else
      end

      raise "Bug: final_if shouldn't be nil" unless final_if

      final_if = final_if.transform(self)
      final_exp = if assign
                    Expressions.new([assign, final_if] of ASTNode)
                  else
                    final_if
                  end
      final_exp.location = node.location
      final_exp
    end

    def transform(node : If)
      if @exception_handler_count > 0
        return super
      end

      node.cond = node.cond.transform(self)

      before_vars = @vars.clone
      then_vars = nil
      else_vars = nil
      then_dead_code = false
      else_dead_code = false

      unless node.then.nop?
        node.then = node.then.transform(self)
        then_vars = @vars.clone
        then_dead_code = @dead_code
      end

      unless node.else.nop?
        if then_vars
          before_else_vars = {} of String => Index
          then_vars.each do |var_name, indices|
            before_indices = before_vars[var_name]?
            read_index = before_indices ? before_indices.read : nil
            before_else_vars[var_name] = Index.new(read_index, indices.write)
          end
          pushing_vars(before_else_vars) do
            node.else = node.else.transform(self)
            else_vars = @vars.clone
          end
        else
          node.else = node.else.transform(self)
          else_vars = @vars.clone
        end
        else_dead_code = @dead_code
      end

      new_then_vars = [] of Assign
      new_else_vars = [] of Assign

      all_vars = [] of String
      all_vars.concat then_vars.keys if then_vars
      all_vars.concat else_vars.keys if else_vars
      all_vars.uniq!

      all_vars.each do |var_name|
        before_indices = before_vars[var_name]?
        then_indices = then_vars && then_vars[var_name]?
        else_indices = else_vars && else_vars[var_name]?

        if else_indices.nil?
          if before_indices
            if then_indices && then_indices != before_indices && then_indices.read
              push_assign_var_with_indices new_then_vars, var_name, then_indices.write, then_indices.read
              push_assign_var_with_indices new_else_vars, var_name, then_indices.write, before_indices.read
              @vars[var_name] = Index.new(then_indices.write, then_indices.write + 1)
            end
          elsif then_indices
            push_assign_var_with_indices new_then_vars, var_name, then_indices.write, then_indices.read
            push_assign_var_with_indices new_else_vars, var_name, then_indices.write, nil
            @vars[var_name] = Index.new(then_indices.write, then_indices.write + 1)
          end
        elsif then_indices.nil?
          if before_indices
            if else_indices && else_indices != before_indices && else_indices.read
              push_assign_var_with_indices new_else_vars, var_name, else_indices.write, else_indices.read
              push_assign_var_with_indices new_then_vars, var_name, else_indices.write, before_indices.read
              @vars[var_name] = Index.new(else_indices.write, else_indices.write + 1)
            end
          elsif else_indices
            push_assign_var_with_indices new_else_vars, var_name, else_indices.write, else_indices.read
            push_assign_var_with_indices new_then_vars, var_name, else_indices.write, nil
            @vars[var_name] = Index.new(else_indices.write, else_indices.write + 1)
          end
        elsif then_indices && else_indices && then_indices != else_indices
          then_write = then_indices.write
          else_write = else_indices.write
          max_write = then_write > else_write ? then_write : else_write
          push_assign_var_with_indices new_then_vars, var_name, max_write, then_indices.read
          push_assign_var_with_indices new_else_vars, var_name, max_write, else_indices.read
          @vars[var_name] = Index.new(max_write, max_write + 1)
        end
      end

      node.then = append_before_exits(node.then, before_vars, new_then_vars) if !node.then.nop? && new_then_vars.length > 0
      unless then_dead_code
        node.then = concat_preserving_return_value(node.then, new_then_vars)
      end

      node.else = append_before_exits(node.else, before_vars, new_else_vars) if !node.else.nop? && new_else_vars.length > 0
      unless else_dead_code
        node.else = concat_preserving_return_value(node.else, new_else_vars)
      end

      @dead_code = then_dead_code && else_dead_code

      node
    end

    # Convert unless to if:
    #
    # From:
    #
    #     unless foo
    #       bar
    #     else
    #       baz
    #     end
    #
    # To:
    #
    #     if foo
    #       baz
    #     else
    #       bar
    #     end
    def transform(node : Unless)
      If.new(node.cond, node.else, node.then).transform(self)
    end

    # Evaluate the ifdef's flags.
    # If they hold, keep the "then" part.
    # If they don't, keep the "else" part.
    def transform(node : IfDef)
      cond_value = eval_flags(node.cond)
      if cond_value
        node.then.transform(self)
      else
        node.else.transform(self)
      end
    end

    def transform(node : While)
      reset_instance_variables_indices

      if @exception_handler_count > 0
        return super
      end

      before_cond_vars = @vars.clone
      node.cond = node.cond.transform(self)
      after_cond_vars = @vars.clone

      node.body = node.body.transform(self)

      after_cond_loop_vars = get_loop_vars(after_cond_vars, false)
      before_cond_loop_vars = get_loop_vars(before_cond_vars, false)

      vars_declared_in_body = [] of String

      @vars.each do |var_name, indices|
        unless var_name[0] == '#'
          before_indices = before_cond_vars[var_name]?
          unless before_indices
            vars_declared_in_body << var_name
          end
        end

        after_indices = after_cond_vars[var_name]?
        if after_indices && after_indices != indices
          @vars[var_name] = Index.new(after_indices.read, indices.write)
        end
      end

      vars_declared_in_body.each do |var_name|
        indices = @vars[var_name]
        before_cond_loop_vars << assign_var_with_indices(var_name, indices.write, indices.read)
        after_cond_loop_vars << assign_var_with_indices(var_name, indices.write, indices.read)
      end

      node.body = append_before_exits(node.body, before_cond_vars, after_cond_loop_vars) if !node.body.nop? && after_cond_loop_vars.length > 0

      unless @dead_code
        node.body = concat_preserving_return_value(node.body, before_cond_loop_vars)

        if vars_declared_in_body.length > 0
          exps = [] of ASTNode
          vars_declared_in_body.each do |var_name|
            indices = @vars[var_name]
            exps << assign_var_with_indices(var_name, indices.write, nil)
            increment_var(var_name, indices)
          end
          exps << node
          node = Expressions.new(exps)
        end
      end

      node
    end

    # Transform require to its source code.
    # The source code can be a Nop if the file was already required.
    def transform(node : Require)
      location = node.location
      required = @program.require(node.string, location.try &.filename).not_nil!
      required.transform(self)
    rescue ex : Crystal::Exception
      node.raise "while requiring \"#{node.string}\"", ex
    rescue ex
      node.raise "while requiring \"#{node.string}\": #{ex.message}"
    end

    def eval_flags(node)
      evaluator = FlagsEvaluator.new(@program)
      node.accept evaluator
      evaluator.value
    end

    class FlagsEvaluator < Visitor
      getter value

      def initialize(@program)
      end

      def visit(node : ASTNode)
        raise "Bug: shouldn't visit #{node} in FlagsEvaluator"
      end

      def visit(node : Var)
        @value = @program.has_flag?(node.name)
      end

      def visit(node : Not)
        node.exp.accept self
        @value = !@value
        false
      end

      def visit(node : And)
        node.left.accept self
        left_value = @value
        node.right.accept self
        @value = left_value && @value
        false
      end

      def visit(node : Or)
        node.left.accept self
        left_value = @value
        node.right.accept self
        @value = left_value || @value
        false
      end
    end

    def get_loop_vars(before_vars, restore = true)
      loop_vars = [] of Assign

      @vars.each do |var_name, indices|
        before_indices = before_vars[var_name]?
        if before_indices
          before_indices_read = before_indices.read
          indices_read = indices.read
          if before_indices_read && indices_read && before_indices_read < indices_read
            loop_vars << assign_var_with_indices(var_name, before_indices_read, indices_read)
            if restore
              @vars[var_name] = Index.new(before_indices_read, indices.write)
            end
          end
        end
      end

      loop_vars
    end

    def pushing_vars_from_args(args)
      vars = {} of String => Index
      args.each { |arg| vars[arg.name] = Index.new }
      pushing_vars(vars) do
        yield
      end
    end

    def pushing_vars(vars = {} of String => Index)
      @vars, old_vars = vars, @vars
      @vars = vars
      @vars_stack.push vars
      yield
      @vars = old_vars
      @vars_stack.pop
    end

    def new_temp_var
      program.new_temp_var
    end

    def assign_var_with_indices(name, to_index, from_index)
      if from_index
        from_var = var_with_index(name, from_index)
      elsif name[0] == '@'
        from_var = InstanceVar.new(name)
      else
        from_var = NilLiteral.new
      end
      Assign.new(var_with_index(name, to_index), from_var)
    end

    def push_assign_var_with_indices(vars, name, to_index, from_index)
      return if to_index == from_index || name[0] == '#'

      # If we need to assign the default value of a varaible inside an if
      # in an initialize, we explicitly set the value to Nil so the type
      # will be nilable even if the instance variable is assigned inside
      # the initialize.
      if @in_initialize && !from_index && name[0] == '@'
        vars << Assign.new(InstanceVar.new(name), NilLiteral.new)
      end

      return if @in_initialize && name[0] == '@'

      vars << assign_var_with_indices(name, to_index, from_index)
    end

    def increment_var(name, indices)
      @vars[name] = indices.increment
    end

    def var_name_with_index(name, index)
      if index && index > 0
        "#{name}$#{index}"
      else
        name
      end
    end

    def var_with_index(name, index)
      Var.new(var_name_with_index(name, index))
    end

    def new_temp_var
      program.new_temp_var
    end

    def concat_preserving_return_value(node, vars)
      return node if vars.empty?

      if node.nop?
        exps = Array(ASTNode).new(vars.length + 1)
        exps.concat vars
        exps.push NilLiteral.new
      else
        temp_var = new_temp_var
        assign = Assign.new(temp_var, node)

        exps = Array(ASTNode).new(vars.length + 2)
        exps.push assign
        exps.concat vars
        exps.push temp_var
      end

      Expressions.new exps
    end

    def append_before_exits(node, before_vars, vars)
      transformer = AppendBeforeExits.new(before_vars, vars)
      node.transform(transformer)
    end

    class AppendBeforeExits < Transformer
      def initialize(before_vars, vars)
        @before_vars = before_vars
        @vars = vars
        @vars_indices = {} of String => String
        @names = Set.new(vars.map { |var| var_name_without_index(var.target) })
        @nest_count = 0
      end

      def transform(node : Assign)
        node = super

        target = node.target
        if target.is_a?(Var)
          name_and_index = target.name.split('$')
          if name_and_index.length == 2
            name, index = name_and_index
            if @names.includes?(name)
              @vars_indices[name] = index
            end
          elsif @names.includes?(target.name)
            @vars_indices[target.name] = "0"
          end
        end

        node
      end

      def transform(node : Break)
        transform_break_or_next(node)
      end

      def transform(node : Next)
        transform_break_or_next(node)
      end

      def transform_break_or_next(node)
        if @nest_count == 0
          new_vars = @vars.map do |assign|
            target = assign.target
            target_name = var_name(target)

            name = var_name_without_index target_name

            value_index = @vars_indices[name]?
            if value_index || ((before_var = @before_vars[name]?) && (value_index = before_var.read))
              new_name = value_index == 0 || value_index == "0" ? name : "#{name}$#{value_index}"
              if target_name == new_name
                nil
              else
                Assign.new(target, Var.new(new_name))
              end
            else
              Assign.new(target, NilLiteral.new)
            end
          end
          new_vars.compact!

          exps = Array(ASTNode).new(new_vars.length + 1)
          new_vars.each do |var|
            exps << var if var
          end
          exps.push node

          Expressions.new exps
        else
          node
        end
      end

      def transform(node : While)
        @nest_count += 1
        node = super
        @nest_count -= 1
        node
      end

      def transform(node : Block)
        @nest_count += 1
        node = super
        @nest_count -= 1
        node
      end

      def var_name(node : Var)
        node.name
      end

      def var_name(node : InstanceVar)
        node.name
      end

      def var_name(node)
        raise "Bug: expected node to be a Var or InstanceVar, not #{node}"
      end

      def var_name_without_index(name : String)
        name_and_index = name.split('$')
        name_and_index.first
      end

      def var_name_without_index(node)
        var_name_without_index(var_name(node))
      end
    end
  end
end
