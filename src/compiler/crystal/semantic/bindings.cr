module Crystal
  class ASTNode
    property! dependencies : Array(ASTNode)
    property freeze_type : Type?
    property observers : Array(ASTNode)?
    property enclosing_call : Call?

    @dirty = false

    @type : Type?

    def type
      @type || ::raise "BUG: `#{self}` at #{self.location} has no type"
    end

    def type?
      @type
    end

    def set_type(type : Type)
      type = type.remove_alias_if_simple
      if !type.no_return? && (freeze_type = @freeze_type) && !type.implements?(freeze_type)
        raise_frozen_type freeze_type, type, self
      end
      @type = type
    end

    def set_type(type : Nil)
      @type = type
    end

    def set_type_from(type, from)
      set_type type
    rescue ex : FrozenTypeException
      # See if we can find where the mismatched type came from
      if from && !ex.inner && (freeze_type = @freeze_type) && type.is_a?(UnionType) && type.includes_type?(freeze_type) && type.union_types.size == 2
        other_type = type.union_types.find { |type| type != freeze_type }
        trace = from.find_owner_trace(freeze_type.program, other_type)
        ex.inner = trace
      end

      if from && !location
        from.raise ex.message, ex.inner
      else
        ::raise ex
      end
    end

    def raise_frozen_type(freeze_type, invalid_type, from)
      if !freeze_type.includes_type?(invalid_type.program.nil) && invalid_type.includes_type?(invalid_type.program.nil)
        # This means that an instance variable become nil
        if self.is_a?(MetaTypeVar) && (nil_reason = self.nil_reason)
          inner = MethodTraceException.new(nil, [] of ASTNode, nil_reason, freeze_type.program.show_error_trace?)
        end
      end

      if self.is_a?(MetaTypeVar)
        if self.global?
          from.raise "global variable '#{self.name}' must be #{freeze_type}, not #{invalid_type}", inner, Crystal::FrozenTypeException
        else
          from.raise "#{self.kind} variable '#{self.name}' of #{self.owner} must be #{freeze_type}, not #{invalid_type}", inner, Crystal::FrozenTypeException
        end
      else
        from.raise "type must be #{freeze_type}, not #{invalid_type}", inner, Crystal::FrozenTypeException
      end
    end

    def type=(type)
      return if @type.same?(type) || (!type && !@type)

      set_type(type)
      notify_observers
      @type
    end

    def bind_to(node : ASTNode)
      bind(node) do |dependencies|
        dependencies.push node
        node.add_observer self
        node
      end
    end

    def bind_to(nodes : Array)
      return if nodes.empty?

      bind do |dependencies|
        dependencies.concat nodes
        nodes.each &.add_observer self
        nodes.first
      end
    end

    def bind(from = nil)
      # Quick check to provide a better error message when assigning a type
      # to a variable whose type is frozen
      if self.is_a?(MetaTypeVar) && (freeze_type = self.freeze_type) && from &&
         (from_type = from.type?) && !from_type.implements?(freeze_type)
        raise_frozen_type freeze_type, from_type, from
      end

      dependencies = @dependencies ||= [] of ASTNode

      node = yield dependencies

      if dependencies.size == 1
        new_type = node.type?
      else
        new_type = Type.merge dependencies
      end
      new_type = map_type(new_type) if new_type

      return if @type.same? new_type
      return unless new_type

      set_type_from(new_type, from)
      @dirty = true
      propagate
    end

    def unbind_all
      @dependencies.try &.each &.remove_observer(self)
      @dependencies = nil
    end

    def unbind_from(nodes : Nil)
      # Nothing to do
    end

    def unbind_from(node : ASTNode)
      @dependencies.try &.reject! &.same?(node)
      node.remove_observer self
    end

    def unbind_from(nodes : Array(ASTNode))
      @dependencies.try &.reject! { |dep| nodes.any? &.same?(dep) }
      nodes.each &.remove_observer self
    end

    def add_observer(observer)
      observers = @observers ||= [] of ASTNode
      observers.push observer
    end

    def remove_observer(observer)
      @observers.try &.reject! &.same?(observer)
    end

    def set_enclosing_call(enclosing_call)
      raise "BUG: already had enclosing call" if @enclosing_call
      @enclosing_call = enclosing_call
    end

    def remove_enclosing_call(enclosing_call)
      @enclosing_call = nil if @enclosing_call.same?(enclosing_call)
    end

    def notify_observers
      @observers.try &.each &.update self
      @enclosing_call.try &.recalculate
      @observers.try &.each &.propagate
      @enclosing_call.try &.propagate
    end

    def update(from = nil)
      return if @type && @type.same? from.try &.type?

      new_type = Type.merge dependencies
      new_type = map_type(new_type) if new_type

      return if @type.same? new_type

      if new_type
        set_type_from(new_type, from)
      else
        return unless @type

        set_type(nil)
      end

      @dirty = true
    end

    def propagate
      if @dirty
        @dirty = false
        notify_observers
      end
    end

    def map_type(type)
      type
    end

    def find_owner_trace(program, owner)
      owner_trace = [] of ASTNode
      node = self

      visited = Set(typeof(object_id)).new
      visited.add node.object_id
      while deps = node.dependencies?
        dependencies = deps.select { |dep| dep.type? && dep.type.includes_type?(owner) && !visited.includes?(dep.object_id) }
        if dependencies.size > 0
          node = dependencies.first
          nil_reason = node.nil_reason if node.is_a?(MetaTypeVar)
          owner_trace << node if node
          visited.add node.object_id
        else
          break
        end
      end

      MethodTraceException.new(owner, owner_trace, nil_reason, program.show_error_trace?)
    end
  end

  class Def
    def map_type(type)
      # When we have Nil forced as a return type, NoReturn still
      # wins, so we must account for this case.
      # Otherwise we simply keep having the Nil type.
      if freeze_type.try &.nil_type? && !type.no_return?
        freeze_type
      else
        type
      end
    end
  end

  class PointerOf
    def map_type(type)
      old_type = self.type?
      new_type = type.try &.program.pointer_of(type)
      if old_type && grew?(old_type, new_type)
        raise "recursive pointerof expansion: #{old_type}, #{new_type}, ..."
      end

      new_type
    end

    def grew?(old_type, new_type)
      new_type = new_type.as(PointerInstanceType)
      element_type = new_type.element_type
      type_includes?(element_type, old_type)
    end

    def type_includes?(haystack, needle)
      return true if haystack == needle

      case haystack
      when UnionType
        haystack.union_types.any? { |sub| type_includes?(sub, needle) }
      when GenericClassInstanceType
        haystack.type_vars.any? { |key, sub| sub.is_a?(Var) && type_includes?(sub.type, needle) }
      else
        false
      end
    end
  end

  class TypeOf
    property? in_type_args = false

    def map_type(type)
      @in_type_args ? type : type.metaclass
    end

    def update(from = nil)
      super
      propagate
    end
  end

  class ExceptionHandler
    def map_type(type)
      if (ensure_type = @ensure.try &.type?).try &.is_a?(NoReturnType)
        ensure_type
      else
        type
      end
    end
  end

  class Cast
    property? upcast = false

    def update(from = nil)
      obj_type = obj.type?
      to_type = to.type

      @upcast = false

      if obj_type && !(obj_type.pointer? || to_type.pointer?)
        filtered_type = obj_type.filter_by(to_type)

        # If the filtered type didn't change it means that an
        # upcast is being made, for example:
        #
        #   1 as Int32 | Float64
        #   Bar.new as Foo # where Bar < Foo
        if obj_type == filtered_type && !to_type.is_a?(GenericClassType) &&
           to_type.allowed_in_generics?
          filtered_type = to_type
          @upcast = true
        end
      end

      # If we don't have a matching type, leave it as the to_type:
      # later (in cleanup) we will check again.
      filtered_type ||= to_type

      self.type = filtered_type.virtual_type
    end
  end

  class NilableCast
    property? upcast = false
    getter! non_nilable_type : Type

    def update(from = nil)
      obj_type = obj.type?
      to_type = to.type

      @upcast = false

      if obj_type
        filtered_type = obj_type.filter_by(to_type)

        # If the filtered type didn't change it means that an
        # upcast is being made, for example:
        #
        #   1 as Int32 | Float64
        #   Bar.new as Foo # where Bar < Foo
        if obj_type == filtered_type && !to_type.is_a?(GenericClassType) &&
           to_type.allowed_in_generics?
          filtered_type = to_type.virtual_type
          @upcast = true
        end
      end

      # If we don't have a matching type, leave it as the to_type:
      # later (in cleanup) we will check again.
      filtered_type ||= to_type
      filtered_type = filtered_type.virtual_type

      @non_nilable_type = filtered_type

      # The final type is nilable
      self.type = filtered_type.program.nilable(filtered_type)
    end
  end

  class ProcLiteral
    property? force_nil = false
    property expected_return_type : Type?

    def update(from = nil)
      return unless self.def.args.all? &.type?
      return unless self.def.type?

      types = self.def.args.map &.type
      return_type = @force_nil ? self.def.type.program.nil : self.def.type

      expected_return_type = @expected_return_type
      if expected_return_type && !expected_return_type.nil_type? && !return_type.implements?(expected_return_type)
        raise "expected block to return #{expected_return_type.devirtualize}, not #{return_type}"
      end

      types << (expected_return_type || return_type)

      self.type = self.def.type.program.proc_of(types)
    end

    def return_type
      @type.as(ProcInstanceType).return_type
    end
  end

  class ProcPointer
    property! call : Call

    def map_type(type)
      return nil unless call.type?

      arg_types = call.args.map &.type
      arg_types.push call.type

      call.type.program.proc_of(arg_types)
    end
  end

  class Generic
    property! instance_type : GenericType
    property scope : Type?
    property? in_type_args = false

    def update(from = nil)
      instance_type = self.instance_type
      if instance_type.is_a?(NamedTupleType)
        entries = named_args.not_nil!.map do |named_arg|
          node = named_arg.value

          if node.is_a?(Path) && (syntax_replacement = node.syntax_replacement)
            node = syntax_replacement
          end

          if node.is_a?(NumberLiteral)
            node.raise "can't use number as type for NamedTuple"
          end

          node_type = node.type?
          return unless node_type

          if node.is_a?(Path) && (target_const = node.target_const)
            node.raise "can't use constant as type for NamedTuple"
          end

          Crystal.check_type_allowed_in_generics(node, node_type, "can't use #{node_type} as generic type argument")
          node_type = node_type.virtual_type

          NamedArgumentType.new(named_arg.name, node_type)
        end

        generic_type = instance_type.instantiate_named_args(entries)
      else
        type_vars_types = Array(TypeVar).new(type_vars.size + 1)
        type_vars.each do |node|
          if node.is_a?(Path) && (syntax_replacement = node.syntax_replacement)
            node = syntax_replacement
          end
          if node.is_a?(SizeOf) && (expanded = node.expanded)
            node = expanded
          end
          if node.is_a?(InstanceSizeOf) && (expanded = node.expanded)
            node = expanded
          end

          case node
          when NumberLiteral
            type_var = node
          when Splat
            type = node.type?
            return unless type.is_a?(TupleInstanceType)

            type_vars_types.concat(type.tuple_types)
            next
          else
            node_type = node.type?
            return unless node_type

            # If the Path points to a constant, we solve it and use it if it's a number literal
            if node.is_a?(Path) && (target_const = node.target_const)
              value = target_const.value
              if value.is_a?(NumberLiteral)
                type_var = value
              else
                # Try to interpret the value
                visitor = target_const.visitor
                if visitor
                  numeric_value = visitor.interpret_enum_value(value)
                  numeric_type = node_type.program.int?(numeric_value) || raise "BUG: expected integer type, not #{numeric_value.class}"
                  type_var = NumberLiteral.new(numeric_value, numeric_type.kind)
                  type_var.set_type_from(numeric_type, from)
                else
                  node.raise "can't use constant #{node} (value = #{value}) as generic type argument, it must be a numeric constant"
                end
              end
            else
              Crystal.check_type_allowed_in_generics(node, node_type, "can't use #{node_type} as generic type argument")
              type_var = node_type.virtual_type
            end
          end

          type_vars_types << type_var
        end

        begin
          generic_type = instance_type.as(GenericType).instantiate(type_vars_types)
        rescue ex : Crystal::Exception
          raise ex.message
        end
      end

      if generic_type_too_nested?(generic_type.generic_nest)
        raise "generic type too nested: #{generic_type}"
      end

      generic_type = generic_type.metaclass unless @in_type_args
      self.type = generic_type
    end
  end

  class TupleLiteral
    property! program : Program

    def update(from = nil)
      return unless elements.all? &.type?

      types = elements.map &.type.as(TypeVar)
      tuple_type = program.tuple_of types

      if generic_type_too_nested?(tuple_type.generic_nest)
        raise "tuple type too nested: #{tuple_type}"
      end

      if types.size > 300
        raise "tuple too big: Tuple(#{types[0...10].join(",")}, ...)"
      end

      self.type = tuple_type
    end
  end

  class NamedTupleLiteral
    property! program : Program

    def update(from = nil)
      return unless entries.all? &.value.type?

      entries = self.entries.map do |element|
        NamedArgumentType.new(element.key, element.value.type)
      end

      named_tuple_type = program.named_tuple_of(entries)

      if generic_type_too_nested?(named_tuple_type.generic_nest)
        raise "named tuple type too nested: #{named_tuple_type}"
      end

      if entries.size > 300
        raise "named tuple too big: #{named_tuple_type}"
      end

      self.type = named_tuple_type
    end
  end

  class ReadInstanceVar
    property! visitor : MainVisitor

    def update(from = nil)
      obj_type = obj.type?
      return unless obj_type

      var = visitor.lookup_instance_var(self, obj_type)
      self.type = var.type
    end
  end

  class Not
    def update(from = nil)
      type = exp.type?
      return unless type

      self.type = type.no_return? ? type : type.program.bool
    end
  end

  class Block
    property binder : YieldBlockBinder?
  end

  # Fictitious node to bind yield expressions to block arguments
  class YieldBlockBinder < ASTNode
    getter block

    def initialize(@program : Program, @block : Block)
      @yields = [] of {Yield, Array(Var)?}
    end

    def add_yield(node : Yield, yield_vars : Array(Var)?)
      @yields << {node, yield_vars}
      node.exps.each &.add_observer(self)
    end

    def update(from = nil)
      # We compute all the types for each block arguments
      args_size = block.args.size
      block_arg_types = Array(Array(Type)?).new(args_size, nil)
      splat_index = block.splat_index

      @yields.each do |a_yield, yield_vars|
        i = 0

        # Gather all exps types and then assign to block_arg_types.
        # We need to do that in case of a block splat argument, we need
        # to split and create tuple types for that case.
        exps_types = Array(Type).new(a_yield.exps.size)

        a_yield.exps.each do |exp|
          exp_type = exp.type?
          return unless exp_type

          if exp.is_a?(Splat)
            unless exp_type.is_a?(TupleInstanceType)
              exp.raise "expected splat expression to be a tuple type, not #{exp_type}"
            end

            exps_types.concat(exp_type.tuple_types)
            i += exp_type.tuple_types.size
          else
            exps_types << exp_type
            i += 1
          end
        end

        # Check if there are missing yield expressions to match
        # the (optional) block signature, and if they match the declared types
        if yield_vars
          if exps_types.size < yield_vars.size
            a_yield.raise "wrong number of yield arguments (given #{exps_types.size}, expected #{yield_vars.size})"
          end

          # Check that the types match
          i = 0
          yield_vars.zip(exps_types) do |yield_var, exp_type|
            unless exp_type.implements?(yield_var.type)
              a_yield.raise "argument ##{i + 1} of yield expected to be #{yield_var.type}, not #{exp_type}"
            end
            i += 1
          end
        end

        # Now move exps_types to block_arg_types
        if splat_index
          # Error if there are less expressions than the number of block arguments
          if exps_types.size < (args_size - 1)
            block.raise "too many block arguments (given #{args_size - 1}+, expected maximum #{exps_types.size}+)"
          end

          j = 0
          args_size.times do |i|
            types = block_arg_types[i] ||= [] of Type
            if i == splat_index
              tuple_types = exps_types[i, exps_types.size - (args_size - 1)]
              types << @program.tuple_of(tuple_types)
              j += tuple_types.size
            else
              types << exps_types[j]
              j += 1
            end
          end
        else
          # Check if tuple unpacking is needed
          if exps_types.size == 1 &&
             (exp_type = exps_types.first).is_a?(TupleInstanceType) &&
             args_size > 1
            if block.args.size > exp_type.tuple_types.size
              block.raise "too many block arguments (given #{block.args.size}, expected maximum #{exp_type.tuple_types.size})"
            end

            exp_type.tuple_types.each_with_index do |tuple_type, i|
              break if i >= block_arg_types.size

              types = block_arg_types[i] ||= [] of Type
              types << tuple_type
            end
          else
            if block.args.size > exps_types.size
              block.raise "too many block arguments (given #{block.args.size}, expected maximum #{exps_types.size})"
            end

            exps_types.each_with_index do |exp_type, i|
              break if i >= block_arg_types.size

              types = block_arg_types[i] ||= [] of Type
              types << exp_type
            end
          end
        end
      end

      block.args.each_with_index do |arg, i|
        block_arg_type = block_arg_types[i]
        if block_arg_type
          arg_type = Type.merge(block_arg_type) || @program.nil
          if i == splat_index && !arg_type.is_a?(TupleInstanceType)
            arg.raise "block splat argument must be a tuple type, not #{arg_type}"
          end
          arg.type = arg_type
        else
          # Skip, no type info found in this position
        end
      end
    end

    def clone_without_location
      self
    end
  end
end

# TODO: 300 is a pretty big number for the number of nested generic instantiations,
# (think Array(Array(Array(Array(Array(Array(Array(Array(Array(Array(Array(...))))))))))
# but we might want to implement an algorithm that correctly identifies this
# infinite recursion.
private def generic_type_too_nested?(nest_level)
  nest_level > 300
end
