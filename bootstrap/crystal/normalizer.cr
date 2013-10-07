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
      getter :read
      getter :write
      getter :frozen

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

    getter :program

    def initialize(@program)
      @vars = {} of String => Index
      @vars_stack = [] of Hash(String, Index)
      @in_initialize = false
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

    def transform(node : And)
      left = node.left
      new_node = if left.is_a?(Var) || (left.is_a?(IsA) && left.obj.is_a?(Var))
               If.new(left, node.right, left.clone)
             else
               temp_var = new_temp_var
               If.new(Assign.new(temp_var, left), node.right, temp_var)
             end
      new_node.binary = :and
      new_node.transform(self)
    end

    def transform(node : Or)
      left = node.left
      new_node = if left.is_a?(Var)
                   If.new(left, left.clone, node.right)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var, left), temp_var, node.right)
                 end
      new_node.binary = :or
      new_node.transform(self)
    end

    # def transform(node : RegexpLiteral)
    #   const_name = "#Regexp_#{node.value}"
    #   unless program.types[const_name]
    #     constructor = Call.new(Ident.new(['Regexp'], true), 'new', [StringLiteral.new(node.value)])
    #     program.types[const_name] = Const.new program, const_name, constructor, [program], program
    #   end

    #   Ident.new([const_name], true)
    # end

    # def transform(node : Require)
    #   if node.cond
    #     must_require = eval_require_cond(node.cond)
    #     return unless must_require
    #   end

    #   required = program.require(node.string, node.filename)
    #   required ? required.transform(self) : nil
    # end

    def transform(node : StringInterpolation)
      super

      call = Call.new(Ident.new(["StringBuilder"], true), "new")
      node.expressions.each do |piece|
        call = Call.new(call, "<<", [piece])
      end
      Call.new(call, "to_s")
    end

    def transform(node : RangeLiteral)
      super

      Call.new(Ident.new(["Range"], true), "new", [node.from, node.to, BoolLiteral.new(node.exclusive)])
    end

    def transform(node : ArrayLiteral)
      super

      if node_of = node.of
        if node.elements.length == 0
          generic = NewGenericClass.new(Ident.new(["Array"], true), [node_of] of ASTNode)
          generic.location = node.location

          call = Call.new(generic, "new")
          call.location = node.location
          return call
        end

        type_var = node_of
      else
        type_var = TypeMerge.new(node.elements)
      end

      length = node.elements.length
      capacity = length < 16 ? 16 : 2 ** Math.log(length, 2).ceil

      generic = NewGenericClass.new(Ident.new(["Array"], true), [type_var] of ASTNode)
      generic.location = node.location

      constructor = Call.new(generic, "new", [NumberLiteral.new(capacity, :i32)] of ASTNode)
      constructor.location = node.location

      temp_var = new_temp_var
      assign = Assign.new(temp_var, constructor)
      assign.location = node.location

      set_length = Call.new(temp_var, "length=", [NumberLiteral.new(length, :i32)] of ASTNode)
      set_length.location = node.location

      exps = [assign, set_length] of ASTNode

      node.elements.each_with_index do |elem, i|
        get_buffer = Call.new(temp_var, "buffer")
        get_buffer.location = node.location

        assign_index = Call.new(get_buffer, "[]=", [NumberLiteral.new(i, :i32), elem] of ASTNode)
        assign_index.location = node.location

        exps << assign_index
      end

      exps << temp_var

      exps = Expressions.new(exps)
      exps.location = node.location
      exps
    end

    def transform(node : HashLiteral)
      super

      if (node_of_key = node.of_key)
        node_of_value = node.of_value
        raise "BUG: node.of_value shouldn't be nil if node.of_key is not nil" unless node_of_value

        type_vars = [node_of_key, node_of_value] of ASTNode
      else
        type_vars = [TypeMerge.new(node.keys), TypeMerge.new(node.values)] of ASTNode
      end

      constructor = Call.new(NewGenericClass.new(Ident.new(["Hash"], true), type_vars), "new")
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
      when Ident
        pushing_vars do
          node.value = node.value.transform(self)
        end
      when InstanceVar
        node.value = node.value.transform(self)
        transform_assign_ivar(node, target)
      else
        node.value = node.value.transform(self)
      end

      node
    end

    def transform_assign_var(node)
      indices = @vars[node.name]?
      if indices
        if indices.frozen || @exception_handler_count > 0
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
      @vars[node.name] = Index.new
      node
    end

    def transform(node : ExceptionHandler)
      @exception_handler_count += 1

      node = super

      @exception_handler_count -= 1

      node
    end

    def transform(node : DeclareVar)
      @vars[node.name] = Index.new
      node
    end

    def transform(node : MultiAssign)
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
          assign = Assign.new(target, call)
          assign.location = target.location
          assigns << assign
        end
        exps = Expressions.new(assigns)
      else
        temp_vars = node.values.map { new_temp_var }

        assign_to_temps = [] of ASTNode
        assign_from_temps = [] of ASTNode

        temp_vars.each_with_index do |temp_var_2, i|
          assign2 = Assign.new(temp_var_2, node.values[i])
          assign2.location = node.location
          assign_to_temps << assign2

          assign2 = Assign.new(node.targets[i], temp_var_2)
          assign2.location = node.location
          assign_from_temps << assign2
        end

        exps = Expressions.new(assign_to_temps + assign_from_temps)
      end
      exps.location = node.location
      exps.transform(self)
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
      return node if @in_initialize

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
      var = node.var

      if var.is_a?(Var)
        name = var.name
        indices = @vars[name]?

        node.var = var.transform(self)

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
      super.tap do
        reset_instance_variables_indices
      end
    end

    def transform(node : Def)
      if node.has_default_arguments?
        exps = [] of ASTNode
        node.expand_default_arguments.each do |exp|
          exps << exp.transform(self)
        end
        return Expressions.new(exps)
      end

      if node.body
        # if node.uses_block_arg
        #   if node.block_arg.type_spec.inputs
        #     args = node.block_arg.type_spec.inputs.each_with_index.map { |input, i| Arg.new("#arg#{i}", nil, input) }
        #     body = Yield.new(args.map { |arg| Var.new(arg.name) })
        #   else
        #     args = [] of Arg
        #     body = Yield.new
        #   end
        #   block_def = FunLiteral.new(Def.new("->", args, body))
        #   assign = Assign.new(Var.new(node.block_arg.name), block_def)

        #   node_body = node.body
        #   if node_body.is_a?(Expressions)
        #     node_body.expressions.unshift(assign)
        #   else
        #     node.body = Expressions.new([assign, node_body])
        #   end
        # end

        pushing_vars_from_args(node.args) do
          @in_initialize = node.name == "initialize"
          node.body = node.body.transform(self)
          @in_initialize = false
        end
      end

      node
    end

    def transform(node : FunDef)
      # if node.body
      #   pushing_vars_from_args(node.args) do
      #     node.body = node.body.transform(self)
      #   end
      # end

      node
    end

    def transform(node : Macro)
      # if node.has_default_arguments?
      #   exps = node.expand_default_arguments.map! { |a_def| a_def.transform(self) }
      #   return Expressions.new(exps)
      # end

      if node.body
        pushing_vars_from_args(node.args) do
          node.body = node.body.transform(self)
        end
      end

      node
    end

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

          if cond.is_a?(Ident)
            comp = IsA.new(right_side, cond)
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

    def transform(node : Unless)
      If.new(node.cond, node.else, node.then).transform(self)
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

      @vars.each do |var_name, indices|
        after_indices = after_cond_vars[var_name]?
        if after_indices && after_indices != indices
          @vars[var_name] = Index.new(after_indices.read, indices.write)
        end
      end

      node.body = append_before_exits(node.body, before_cond_vars, after_cond_loop_vars) if !node.body.nop? && after_cond_loop_vars.length > 0

      unless @dead_code
        node.body = concat_preserving_return_value(node.body, before_cond_loop_vars)
      end

      node
    end

    def transform(node : Block)
      return super if @in_initialize

      before_vars = @vars.clone

      node.args.each do |arg|
        @vars[arg.name] = Index.new
      end

      transformed = super

      if @exception_handler_count > 0
        return transformed
      end

      node.args.each do |arg|
        @vars.delete arg.name
      end

      after_body_vars = get_loop_vars(before_vars)

      node.body = append_before_exits(node.body, before_vars, after_body_vars) if node.body && after_body_vars.length > 0

      unless @dead_code
        node.body = concat_preserving_return_value(node.body, after_body_vars)
      end

      # Delete vars declared inside the block
      block_vars = @vars.keys - before_vars.keys
      block_vars.each do |block_var|
        @vars.delete block_var
      end

      node
    end

    def transform(node : Require)
      location = node.location
      raise "Bug: location is nil" unless location

      required = @program.require(node.string, location.filename)
      required ? required.transform(self) : Nop.new
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
        "#{name}:#{index}"
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
        @names = Set.new(vars.map do |var|
          target = var.target
          raise "BUG: target is not a Var" unless target.is_a?(Var)
          var_name_without_index(target.name)
        end)
        @nest_count = 0
      end

      def transform(node : Assign)
        node = super

        target = node.target
        if target.is_a?(Var)
          name_and_index = target.name.split(':')
          if name_and_index.length == 2
            name, index = name_and_index
            if index && @names.includes?(name)
              @vars_indices[name] = index
            end
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
            raise "BUG: target is not a Var" unless target.is_a?(Var)

            name = var_name_without_index target.name

            value_index = @vars_indices[name]?
            if value_index || ((before_var = @before_vars[name]?) && (value_index = before_var.read))
              new_name = value_index == 0 ? name : "#{name}:#{value_index}"
              if target.name == new_name
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

      def var_name_without_index(name)
        name_and_index = name.split(':')
        name_and_index.first
      end
    end
  end
end
