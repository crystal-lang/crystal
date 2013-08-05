require_relative "program"
require_relative "transformer"
require "set"

module Crystal
  class Program
    def normalize(node)
      return nil unless node
      normalizer = Normalizer.new(self)
      node = normalizer.normalize(node)
      puts node if ENV['SSA'] == '1'
      node
    end
  end

  class Normalizer < Transformer
    attr_reader :program

    def initialize(program)
      @program = program
      @vars = {}
      @vars_stack = []
      @in_initialize = false
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

    def transform_expressions(node)
      exps = []
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
        nil
      when 1
        exps[0]
      else
        node.expressions = exps
        node
      end
    end

    def transform_and(node)
      new_node = if node.left.is_a?(Var) || (node.left.is_a?(IsA) && node.left.obj.is_a?(Var))
               If.new(node.left, node.right, node.left.clone)
             else
               temp_var = new_temp_var
               If.new(Assign.new(temp_var, node.left), node.right, temp_var)
             end
      new_node.binary = :and
      new_node.transform(self)
    end

    def transform_or(node)
      new_node = if node.left.is_a?(Var)
                   If.new(node.left, node.left.clone, node.right)
                 else
                   temp_var = new_temp_var
                   If.new(Assign.new(temp_var, node.left), temp_var, node.right)
                 end
      new_node.binary = :or
      new_node.transform(self)
    end

    def transform_require(node)
      required = program.require(node.string.value, node.filename)
      required ? required.transform(self) : nil
    end

    def transform_string_interpolation(node)
      super

      call = Call.new(Ident.new(["StringBuilder"], true), "new")
      node.expressions.each do |piece|
        call = Call.new(call, :<<, [piece])
      end
      Call.new(call, "to_s")
    end

    def transform_def(node)
      if node.has_default_arguments?
        exps = node.expand_default_arguments.map! { |a_def| a_def.transform(self) }
        return Expressions.new(exps)
      end

      if node.body
        pushing_vars(Hash[node.args.map { |arg| [arg.name, {read: 0, write: 1}] }]) do
          @in_initialize = node.name == 'initialize'
          node.body = node.body.transform(self)
          @in_initialize = false
        end
      end

      node
    end

    def transform_macro(node)
      # if node.has_default_arguments?
      #   exps = node.expand_default_arguments.map! { |a_def| a_def.transform(self) }
      #   return Expressions.new(exps)
      # end

      if node.body
        pushing_vars(Hash[node.args.map { |arg| [arg.name, {read: 0, write: 1}] }]) do
          node.body = node.body.transform(self)
        end
      end

      node
    end

    def transform_unless(node)
      If.new(node.cond, node.else, node.then).transform(self)
    end

    def transform_call(node)
      super.tap do
        reset_instance_variables_indices
      end
    end

    def transform_yield(node)
      super.tap do
        reset_instance_variables_indices
      end
    end

    def reset_instance_variables_indices
      @vars.each do |key, value|
        if key[0] == '@'
          @vars[key] = {read: nil, write: value[:write]}
        end
      end
    end

    def transform_case(node)
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

          comp = Call.new(cond, :'===', [right_side])
          if final_comp
            final_comp = SimpleOr.new(final_comp, comp)
          else
            final_comp = comp
          end
        end
        wh_if = If.new(final_comp, wh.body)
        if a_if
          a_if.else = wh_if
        else
          final_if = wh_if
        end
        a_if = wh_if
      end
      a_if.else = node.else if node.else
      final_if = final_if.transform(self)
      final_exp = if assign
                    Expressions.new([assign, final_if])
                  else
                    final_if
                  end
      final_exp.location = node.location
      final_exp
    end

    def transform_range_literal(node)
      super

      Call.new(Ident.new(['Range'], true), 'new', [node.from, node.to, BoolLiteral.new(node.exclusive)])
    end

    def transform_regexp_literal(node)
      const_name = "#Regexp_#{node.value}"
      unless program.types[const_name]
        constructor = Call.new(Ident.new(['Regexp'], true), 'new', [StringLiteral.new(node.value)])
        program.types[const_name] = Const.new program, const_name, constructor, [program], program
      end

      Ident.new([const_name], true)
    end

    def transform_array_literal(node)
      super

      if node.of
        if node.elements.length == 0
          return Call.new(NewGenericClass.new(Ident.new(['Array'], true), [node.of]), 'new')
        end

        type_var = node.of
      else
        type_var = TypeMerge.new(node.elements)
      end

      length = node.elements.length
      capacity = length < 16 ? 16 : 2 ** Math.log(length, 2).ceil

      constructor = Call.new(NewGenericClass.new(Ident.new(['Array'], true), [type_var]), 'new', [NumberLiteral.new(capacity, :i32)])
      temp_var = new_temp_var
      assign = Assign.new(temp_var, constructor)
      set_length = Call.new(temp_var, 'length=', [NumberLiteral.new(length, :i32)])

      exps = [assign, set_length]

      node.elements.each_with_index do |elem, i|
        get_buffer = Call.new(temp_var, 'buffer')
        assign_index = Call.new(get_buffer, :[]=, [NumberLiteral.new(i, :i32), elem])
        exps << assign_index
      end

      exps << temp_var

      Expressions.new(exps)
    end

    def transform_hash_literal(node)
      super

      if node.of_key
        type_vars = [node.of_key, node.of_value]
      else
        type_vars = [TypeMerge.new(node.keys), TypeMerge.new(node.values)]
      end

      constructor = Call.new(NewGenericClass.new(Ident.new(['Hash'], true), type_vars), 'new')
      if node.keys.length == 0
        constructor
      else
        temp_var = new_temp_var
        assign = Assign.new(temp_var, constructor)

        exps = [assign]
        node.keys.each_with_index do |key, i|
          exps << Call.new(temp_var, :[]=, [key, node.values[i]])
        end
        exps << temp_var
        Expressions.new exps
      end
    end

    def transform_assign(node)
      case node.target
      when Var
        node.value = node.value.transform(self)
        transform_assign_var(node.target)
      when Ident
        pushing_vars do
          node.value = node.value.transform(self)
        end
      when InstanceVar
        node.value = node.value.transform(self)
        transform_assign_ivar(node)
      else
        node.value = node.value.transform(self)
      end

      node
    end

    def transform_assign_var(node)
      indices = @vars[node.name]
      if indices
        if indices[:frozen]
          node.name = var_name_with_index(node.name, indices[:read])
        else
          increment_var node.name, indices
          node.name = var_name_with_index(node.name, indices[:write])
        end
      else
        @vars[node.name] = {read: 0, write: 1}
      end
    end

    def transform_assign_ivar(node)
      indices = @vars[node.target.name]
      if indices
        indices = increment_var node.target.name, indices
      else
        indices = @vars[node.target.name] = {read: 1, write: 2}
      end

      ivar_name = var_name_with_index(node.target.name, indices[:read])
      node.value = Assign.new(Var.new(ivar_name), node.value)
    end

    def transform_declare_var(node)
      @vars[node.name] = {read: 0, write: 1}
      node
    end

    def transform_if(node)
      node.cond = node.cond.transform(self)

      before_vars = @vars.clone
      then_vars = nil
      else_vars = nil

      if node.then
        node.then = node.then.transform(self)
        then_vars = @vars.clone
        then_dead_code = @dead_code
      end

      if node.else
        if then_vars
          before_else_vars = {}
          then_vars.each do |var_name, indices|
            before_indices = before_vars[var_name]
            read_index = before_indices ? before_indices[:read] : nil
            before_else_vars[var_name] = {read: read_index, write: indices[:write]}
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

      new_then_vars = []
      new_else_vars = []

      all_vars = []
      all_vars.concat then_vars.keys if then_vars
      all_vars.concat else_vars.keys if else_vars
      all_vars.uniq!

      all_vars.each do |var_name|
        before_indices = before_vars[var_name]
        then_indices = then_vars && then_vars[var_name]
        else_indices = else_vars && else_vars[var_name]
        if else_indices.nil?
          if before_indices
            if then_indices != before_indices && then_indices[:read]
              push_assign_var_with_indices new_then_vars, var_name, then_indices[:write], then_indices[:read]
              push_assign_var_with_indices new_else_vars, var_name, then_indices[:write], before_indices[:read]
              @vars[var_name] = {read: then_indices[:write], write: then_indices[:write] + 1}
            end
          else
            push_assign_var_with_indices new_then_vars, var_name, then_indices[:write], then_indices[:read]
            push_assign_var_with_indices new_else_vars, var_name, then_indices[:write], nil
            @vars[var_name] = {read: then_indices[:write], write: then_indices[:write] + 1}
          end
        elsif then_indices.nil?
          if before_indices
            if else_indices != before_indices && else_indices[:read]
              push_assign_var_with_indices new_else_vars, var_name, else_indices[:write], else_indices[:read]
              push_assign_var_with_indices new_then_vars, var_name, else_indices[:write], before_indices[:read]
              @vars[var_name] = {read: else_indices[:write], write: else_indices[:write] + 1}
            end
          else
            push_assign_var_with_indices new_else_vars, var_name, else_indices[:write], else_indices[:read]
            push_assign_var_with_indices new_then_vars, var_name, else_indices[:write], nil
            @vars[var_name] = {read: else_indices[:write], write: else_indices[:write] + 1}
          end
        elsif then_indices != else_indices
          then_write = then_indices[:write]
          else_write = else_indices[:write]
          max_write = then_write > else_write ? then_write : else_write
          push_assign_var_with_indices new_then_vars, var_name, max_write, then_indices[:read]
          push_assign_var_with_indices new_else_vars, var_name, max_write, else_indices[:read]
          @vars[var_name] = {read: max_write, write: max_write + 1}
        end
      end

      node.then = append_before_exits(node.then, before_vars, new_then_vars) if node.then && new_then_vars.length > 0
      unless then_dead_code
        node.then = concat_preserving_return_value(node.then, new_then_vars)
      end

      node.else = append_before_exits(node.else, before_vars, new_else_vars) if node.else && new_else_vars.length > 0
      unless else_dead_code
        node.else = concat_preserving_return_value(node.else, new_else_vars)
      end

      @dead_code = then_dead_code && else_dead_code

      node
    end

    def transform_while(node)
      reset_instance_variables_indices

      before_cond_vars = @vars.clone
      node.cond = node.cond.transform(self)
      after_cond_vars = @vars.clone

      node.body = node.body.transform(self) if node.body

      after_cond_loop_vars = get_loop_vars(after_cond_vars, false)
      before_cond_loop_vars = get_loop_vars(before_cond_vars, false)

      @vars.each do |var_name, indices|
        after_indices = after_cond_vars[var_name]
        if after_indices && after_indices != indices
          @vars[var_name] = {read: after_indices[:read], write: indices[:write]}
        end
      end

      node.body = append_before_exits(node.body, before_cond_vars, after_cond_loop_vars) if node.body && after_cond_loop_vars.length > 0

      unless @dead_code
        node.body = concat_preserving_return_value(node.body, before_cond_loop_vars)
      end

      node
    end

    def transform_block(node)
      before_vars = @vars.clone

      node.args.each do |arg|
        @vars[arg.name] = {read: 0, write: 1}
      end

      super

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

    def concat_preserving_return_value(node, vars)
      return node if vars.empty?

      unless node
        return Expressions.from(vars + [NilLiteral.new])
      end

      temp_var = new_temp_var
      assign = Assign.new(temp_var, node)

      Expressions.concat(assign, vars + [temp_var])
    end

    def increment_var(name, indices = @vars[name])
      @vars[name] = {read: indices[:write], write: indices[:write] + 1}
    end

    def get_loop_vars(before_vars, restore = true)
      loop_vars = []

      @vars.each do |var_name, indices|
        before_indices = before_vars[var_name]
        if before_indices && before_indices[:read] && indices[:read] && before_indices[:read] < indices[:read]
          loop_vars << assign_var_with_indices(var_name, before_indices[:read], indices[:read])
          if restore
            @vars[var_name] = {read: before_indices[:read], write: indices[:write]}
          end
        end
      end

      loop_vars
    end

    def transform_var(node)
      return node if node.name == 'self' || node.name.start_with?('#')

      if node.out
        @vars[node.name] = {read: 0, write: 1}
        return node
      end

      indices = @vars[node.name]
      node.name = var_name_with_index(node.name, indices ? indices[:read] : nil)
      node
    end

    def transform_instance_var(node)
      indices = @vars[node.name]
      if indices && indices[:read]
        new_var = var_with_index(node.name, indices[:read])
        new_var.location = node.location
        new_var
      else
        if @in_initialize
          node
        else
          if indices
            read_index = indices[:write]
          else
            read_index = 1
          end
          @vars[node.name] = {read: read_index, write: read_index + 1}
          new_var = var_with_index(node.name, read_index)
          new_var.location = node.location
          assign = Assign.new(new_var, node)
          assign.location = node.location
          assign
        end
      end
    end

    def transform_pointer_of(node)
      return node if node.var.is_a?(InstanceVar)

      name = node.var.name
      indices = @vars[name]

      node.var = node.var.transform(self)

      if indices
        @vars[name][:frozen] = true
      else
        @vars[name] = {frozen: true, read: 0, write: 1}
      end
      node
    end

    def transform_multi_assign(node)
      if node.values.length == 1
        value = node.values[0]

        temp_var = @program.new_temp_var

        assigns = []

        assign = Assign.new(temp_var, value)
        assign.location = value.location
        assigns << assign

        node.targets.each_with_index do |target, i|
          call = Call.new(temp_var, :[], [NumberLiteral.new(i, :i32)])
          call.location = value.location
          assign = Assign.new(target, call)
          assign.location = target.location
          assigns << assign
        end
        exps = Expressions.new(assigns)
      else
        temp_vars = node.values.map { @program.new_temp_var }

        assign_to_temps = []
        assign_from_temps = []

        temp_vars.each_with_index do |temp_var, i|
          assign = Assign.new(temp_var, node.values[i])
          assign.location = node.location
          assign_to_temps << assign

          assign = Assign.new(node.targets[i], temp_var)
          assign.location = node.location
          assign_from_temps << assign
        end

        exps = Expressions.new(assign_to_temps + assign_from_temps)
      end
      exps.location = node.location
      exps.transform(self)
    end

    def pushing_vars(vars = {})
      @vars, old_vars = vars, @vars
      @vars = vars
      @vars_stack.push vars
      yield
      @vars = old_vars
      @vars_stack.pop
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

      vars << assign_var_with_indices(name, to_index, from_index)
    end

    def append_before_exits(node, before_vars, vars)
      transformer = AppendBeforeExits.new(before_vars, vars)
      node.transform(transformer)
    end
  end

  class AppendBeforeExits < Transformer
    def initialize(before_vars, vars)
      @before_vars = before_vars
      @vars = vars
      @vars_indices = {}
      @names = Set.new(vars.map { |var| var_name_without_index(var.target.name) })
      @nest_count = 0
    end

    def transform_assign(node)
      node = super

      if node.target.is_a?(Var)
        name, index = node.target.name.split(':')
        if index && @names.include?(name)
          @vars_indices[name] = index
        end
      end

      node
    end

    def transform_break(node)
      transform_break_or_next(node)
    end

    def transform_next(node)
      transform_break_or_next(node)
    end

    def transform_break_or_next(node)
      if @nest_count == 0
        new_vars = @vars.map do |assign|
          target = assign.target
          name, index = target.name.split(':')
          value_index = @vars_indices[name]
          if value_index || ((before_var = @before_vars[name]) && (value_index = before_var[:read]))
            new_name = value_index == 0 ? name : "#{name}:#{value_index}"
            if assign.target.name == new_name
              nil
            else
              Assign.new(assign.target, Var.new(new_name))
            end
          else
            Assign.new(assign.target, NilLiteral.new)
          end
        end
        new_vars.compact!
        Expressions.from(new_vars + [node])
      else
        node
      end
    end

    def transform_while(node)
      @nest_count += 1
      node = super
      @nest_count -= 1
      node
    end

    def transform_block(node)
      @nest_count += 1
      node = super
      @nest_count -= 1
      node
    end

    def var_name_without_index(name)
      name, index = name.split(':')
      name
    end
  end
end
