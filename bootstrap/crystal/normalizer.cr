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

    def transform(node : RangeLiteral)
      super

      Call.new(Ident.new(["Range"], true), "new", [node.from, node.to, BoolLiteral.new(node.exclusive)])
    end

    def transform(node : Assign)
      target = node.target
      case target
      when Var
        node.value = node.value.transform(self)
        transform_assign_var(target)
      # when Ident
      #   pushing_vars do
      #     node.value = node.value.transform(self)
      #   end
      # when InstanceVar
      #   node.value = node.value.transform(self)
      #   transform_assign_ivar(node)
      # else
      #   node.value = node.value.transform(self)
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

    def transform(node : Block)
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
