require "../syntax/ast"

# TODO: 10 is a pretty big number for the number of nested generic instantiations,
# (think Array(Array(Array(Array(Array(Array(Array(Array(Array(Array(Array(...))))))))))
# but we might want to implement an algorithm that correctly identifies this
# infinite recursion.
private def generic_type_too_nested?(nest_level)
  nest_level > 10
end

module Crystal
  def self.check_type_allowed_in_generics(node, type, msg)
    return if type.allowed_in_generics?

    type = type.union_types.find { |t| !t.allowed_in_generics? } if type.is_a?(UnionType)
    node.raise "#{msg} yet, use a more specific type"
  end

  class ASTNode
    property! dependencies : Dependencies
    property freeze_type : Type?
    property observers : Dependencies?
    property input_observer : Call?

    @dirty = false
    @propagating_after_cleanup = false

    @type : Type?

    def type
      @type || ::raise "Bug: `#{self}` at #{self.location} has no type"
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
        trace = from.find_owner_trace(other_type)
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
          inner = MethodTraceException.new(nil, [] of ASTNode, nil_reason)
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

    def map_type(type)
      type
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

      dependencies = @dependencies ||= Dependencies.new

      node = yield dependencies

      if dependencies.size == 1
        new_type = node.type?
      else
        new_type = Type.merge dependencies
      end
      return if @type.same? new_type
      return unless new_type

      set_type_from(map_type(new_type), from)
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

    def unbind_from(nodes : Array)
      nodes.each do |node|
        unbind_from node
      end
    end

    def unbind_from(nodes : Dependencies)
      nodes.each do |node|
        unbind_from node
      end
    end

    def add_observer(observer)
      observers = (@observers ||= Dependencies.new)
      observers.push observer
    end

    def remove_observer(observer)
      @observers.try &.reject! &.same?(observer)
    end

    def add_input_observer(observer)
      raise "Bug: already had input observer" if @input_observer
      @input_observer = observer
    end

    def remove_input_observer(observer)
      @input_observer = nil if @input_observer.same?(observer)
    end

    def notify_observers
      @observers.try &.each &.update self
      @input_observer.try &.update_input self
      @observers.try &.each &.propagate
      @input_observer.try &.propagate
    end

    def update(from)
      return if @propagating_after_cleanup
      return if @type.same? from.type?

      if dependencies.size == 1 || !@type
        new_type = from.type?
      else
        new_type = Type.merge dependencies
      end

      if @type.same? new_type
        # If we are in the cleanup phase it might happen that a dependency's
        # type changed (from) but our type didn't. This might happen if
        # there's a circular dependencies in nodes (while and blocks can
        # cause this), so we basically need to recompute all types in the
        # cycle (and depending types).
        #
        # To solve this, we set our type to NoReturn so observers
        # compute their type without taking this note into account.
        # Later, we compute our type from our dependencies and propagate
        # types as usual.
        #
        # To avoid infinite recursion we use the `@propagating_after_cleanup`
        # flag, which prevents computing and propagating types for this
        # node while we are doing the above logic.
        if dependencies.size > 0 && (from_type = from.type?) && from_type.program.in_cleanup_phase?
          set_type(from_type.program.no_return)

          @propagating_after_cleanup = true
          @dirty = true
          propagate

          new_type = Type.merge dependencies
          if new_type
            set_type_from(map_type(new_type), from)
          else
            unless @type
              @propagating_after_cleanup = false
              return
            end
            set_type(nil)
          end

          @dirty = true
          propagate
          @propagating_after_cleanup = false
          return
        else
          return
        end
      end

      if new_type
        set_type_from(map_type(new_type), from)
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

    def raise(message, inner = nil, exception_type = Crystal::TypeException)
      ::raise exception_type.for_node(self, message, inner)
    end

    def find_owner_trace(owner)
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

      MethodTraceException.new(owner, owner_trace, nil_reason)
    end

    def simple_literal?
      case self
      when Nop, NilLiteral, BoolLiteral, NumberLiteral, CharLiteral,
           StringLiteral, SymbolLiteral
        true
      else
        false
      end
    end
  end

  class Var
    def initialize(@name : String, @type : Type)
    end

    def_equals name, type?
  end

  # Fictitious node to represent primitives
  class Primitive < ASTNode
    getter name : String

    def self.new(name : Symbol, type : Type? = nil)
      new(name.to_s, type)
    end

    def initialize(@name : String, @type : Type? = nil)
    end

    def clone_without_location
      Primitive.new(@name, @type)
    end

    def_equals_and_hash name
  end

  # Fictitious node to represent a tuple indexer
  class TupleIndexer < Primitive
    getter index : Int32

    def initialize(@index : Int32)
      super("tuple_indexer_known_index")
    end

    def clone_without_location
      TupleIndexer.new(index)
    end

    def_equals_and_hash index
  end

  # Fictitious node to represent a type
  class TypeNode < ASTNode
    def initialize(@type : Type)
    end

    def to_macro_id
      @type.to_s
    end

    def clone_without_location
      self
    end

    def_equals_and_hash type
  end

  class Arg
    def initialize(@name : String, @default_value : ASTNode? = nil, @restriction : ASTNode? = nil, external_name : String? = nil, @type : Type? = nil)
      @external_name = external_name || @name
    end

    def clone_without_location
      arg = previous_def

      # An arg's type can sometimes be used as a restriction,
      # and must be preserved when cloned
      arg.set_type @type

      arg
    end
  end

  class Def
    property! owner : Type
    property! original_owner : Type
    property vars : MetaVars?
    property yield_vars : Array(Var)?
    getter raises = false
    property closure = false
    property self_closured = false
    property previous : DefWithMetadata?
    property next : Def?
    getter special_vars : Set(String)?
    property block_nest = 0
    property? captured_block = false

    # Is this a `new` method that was expanded from an initialize?
    property? new = false

    @macro_owner : Type?

    def macro_owner=(@macro_owner)
    end

    def macro_owner
      @macro_owner || @owner
    end

    def macro_owner?
      @macro_owner
    end

    def add_special_var(name)
      special_vars = @special_vars ||= Set(String).new
      special_vars << name
    end

    def raises=(value)
      if value != @raises
        @raises = value
        @observers.try &.each do |obs|
          if obs.is_a?(Call)
            obs.raises = value
          end
        end
      end
    end

    def clone_without_location
      a_def = previous_def
      a_def.raises = raises
      a_def.previous = previous
      a_def
    end

    # Yields `arg, arg_index, object, object_index` corresponding
    # to arguments matching the given objects, taking into account this
    # def's splat index.
    def match(objects, &block)
      Splat.match(self, objects) do |arg, arg_index, object, object_index|
        yield arg, arg_index, object, object_index
      end
    end

    def map_type(type)
      # If the return type is nil, our type is nil
      if freeze_type.try &.nil_type?
        freeze_type
      else
        type
      end
    end
  end

  class Macro
    # Yields `arg, arg_index, object, object_index` corresponding
    # to arguments matching the given objects, taking into account this
    # macro's splat index.
    def match(objects, &block)
      Splat.match(self, objects) do |arg, arg_index, object, object_index|
        yield arg, arg_index, object, object_index
      end
    end
  end

  class Splat
    # Yields `arg, arg_index, object, object_index` corresponding
    # to def arguments matching the given objects, taking into account the
    # def's splat index.
    def self.match(a_def, objects, &block)
      Splat.before(a_def, objects) do |arg, arg_index, object, object_index|
        yield arg, arg_index, object, object_index
      end
      Splat.at(a_def, objects) do |arg, arg_index, object, object_index|
        yield arg, arg_index, object, object_index
      end
    end

    # Yields `arg, arg_index, object, object_index` corresponding
    # to arguments before a def's splat index, matching the given objects.
    # If there are more objects than arguments in the method, they are not yielded.
    # If splat index is `nil`, all args and objects (with their indices) are yielded.
    def self.before(a_def, objects, &block)
      splat = a_def.splat_index || a_def.args.size
      splat.times do |i|
        obj = objects[i]?
        break unless obj

        yield a_def.args[i], i, obj, i
        i += 1
      end
      nil
    end

    # Yields `arg, arg_index, object, object_index` corresponding
    # to arguments at a def's splat index, matching the given objects.
    # If there are more objects than arguments in the method, they are not yielded.
    # If splat index is `nil`, all args and objects (with their indices) are yielded.
    def self.at(a_def, objects, &block)
      splat_index = a_def.splat_index
      return unless splat_index

      splat_size = Splat.size(a_def, objects, splat_index)
      splat_size.times do |i|
        obj_index = splat_index + i
        obj = objects[obj_index]?
        break unless obj

        yield a_def.args[splat_index], splat_index, obj, obj_index
      end

      nil
    end

    # Returns the splat size of this def matching the given objects.
    def self.size(a_def, objects, splat_index = a_def.splat_index)
      if splat_index
        objects.size - splat_index
      else
        0
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
    property in_type_args = false

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
      to_type = to.type

      obj_type = obj.type?

      # If we don't know what type we are casting from, leave it as the to_type
      unless obj_type
        self.type = to_type.virtual_type
        return
      end

      if obj_type.pointer? || to_type.pointer?
        self.type = to_type
      else
        filtered_type = obj_type.filter_by(to_type)

        # If the filtered type didn't change it means that an
        # upcast is being made, for example:
        #
        #   1 as Int32 | Float64
        #   Bar.new as Foo # where Bar < Foo
        if obj_type == filtered_type && obj_type != to_type && !to_type.is_a?(GenericClassType)
          filtered_type = to_type.virtual_type
          @upcast = true
        end

        # If we don't have a matching type, leave it as the to_type:
        # later (in after type inference) we will check again.
        filtered_type ||= to_type.virtual_type

        self.type = filtered_type
      end
    end
  end

  class NilableCast
    property? upcast = false
    getter! non_nilable_type : Type

    def update(from = nil)
      to_type = to.type

      obj_type = obj.type?

      # If we don't know what type we are casting from, leave it as nilable to_type
      unless obj_type
        @non_nilable_type = non_nilable_type = to_type.virtual_type

        self.type = to_type.program.nilable(non_nilable_type)
        return
      end

      filtered_type = obj_type.filter_by(to_type)

      # If the filtered type didn't change it means that an
      # upcast is being made, for example:
      #
      #   1 as Int32 | Float64
      #   Bar.new as Foo # where Bar < Foo
      if obj_type == filtered_type && obj_type != to_type && !to_type.is_a?(GenericClassType)
        filtered_type = to_type.virtual_type
        @upcast = true
      end

      # If we don't have a matching type, leave it as the to_type:
      # later (in after type inference) we will check again.
      filtered_type ||= to_type.virtual_type

      @non_nilable_type = filtered_type

      # The final type is nilable
      self.type = filtered_type.program.nilable(filtered_type)
    end
  end

  class FunDef
    property! external : External
  end

  class ProcLiteral
    property force_nil = false
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

  class Generic
    property! instance_type : GenericClassType
    property scope : Type?
    property in_type_args = false

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
                  numeric_type = node_type.program.int?(numeric_value) || raise "Bug: expected integer type, not #{numeric_value.class}"
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
          generic_type = instance_type.instantiate(type_vars_types)
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
    property! mod : Program

    def update(from = nil)
      return unless elements.all? &.type?

      types = elements.map { |exp| exp.type.as(TypeVar) }
      tuple_type = mod.tuple_of types

      if generic_type_too_nested?(tuple_type.generic_nest)
        raise "tuple type too nested: #{tuple_type}"
      end

      self.type = tuple_type
    end
  end

  class NamedTupleLiteral
    property! mod : Program

    def update(from = nil)
      return unless entries.all? &.value.type?

      entries = entries.map do |element|
        NamedArgumentType.new(element.key, element.value.type)
      end

      named_tuple_type = mod.named_tuple_of(entries)

      if generic_type_too_nested?(named_tuple_type.generic_nest)
        raise "named tuple type too nested: #{named_tuple_type}"
      end

      self.type = named_tuple_type
    end
  end

  class ReadInstanceVar
    property! visitor : MainVisitor
    property var : MetaTypeVar?

    def update(from = nil)
      obj_type = obj.type?
      return unless obj_type

      var = visitor.lookup_instance_var(self, obj_type)
      @var = var
      self.type = var.type
    end
  end

  class Not
    def update(from = nil)
      exp_type = exp.type?
      return unless exp_type

      if exp_type.no_return?
        self.type = exp_type
      else
        self.type = exp_type.program.bool
      end
    end
  end

  class MetaVar < ASTNode
    include SpecialVar

    property name : String

    # True if we need to mark this variable as nilable
    # if this variable is read.
    property nil_if_read = false

    # This is the context of the variable: who allocates it.
    # It can either be the Program (for top level variables),
    # a Def or a Block.
    property context : ASTNode | NonGenericModuleType | Nil

    # A variable is closured if it's used in a ProcLiteral context
    # where it wasn't created.
    property closured = false

    # Is this metavar assigned a value?
    property assigned_to = false

    def initialize(@name : String, @type : Type? = nil)
    end

    # True if this variable belongs to the given context
    # but must be allocated in a closure.
    def closure_in?(context)
      closured && belongs_to?(context)
    end

    # True if this variable belongs to the given context.
    def belongs_to?(context)
      @context.same?(context)
    end

    def ==(other : self)
      name == other.name
    end

    def clone_without_location
      self
    end

    def inspect(io)
      io << name
      if type = type?
        io << " : "
        type.to_s(io)
      end
      io << " (nil-if-read)" if nil_if_read
      io << " (closured)" if closured
      io << " (assigned-to)" if assigned_to
      io << " (object id: #{object_id})"
    end
  end

  alias MetaVars = Hash(String, MetaVar)

  # A variable belonging to a type: a global,
  # class or instance variable (globals belong to the program).
  class MetaTypeVar < Var
    property nil_reason : NilReason?

    # The owner of this variable, useful for showing good
    # error messages.
    property! owner : Type

    # Is this variable thread local? Only applicable
    # to global and class variables.
    property? thread_local = false

    # The (optional) initial value of a class variable
    property initializer : ClassVarInitializer?

    def kind
      case name[0]
      when '@'
        if name[1] == '@'
          :class
        else
          :instance
        end
      else
        :global
      end
    end

    def global?
      kind == :global
    end
  end

  class ClassVar
    # The "real" variable associated with this node,
    # belonging to a type.
    property! var : MetaTypeVar
  end

  class Global
    property! var : MetaTypeVar
  end

  class Path
    property target_const : Const?
    property syntax_replacement : ASTNode?
  end

  class Call
    property before_vars : MetaVars?

    def clone_without_location
      cloned = previous_def

      # This is needed because this call might have resolved
      # to a macro and has an expansion.
      cloned.expanded = expanded.clone

      cloned
    end
  end

  # Fictitious node to bind yield expressions to block arguments
  class YieldBlockBinder < ASTNode
    getter block

    def initialize(@mod : Program, @block : Block)
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

      @yields.each do |(a_yield, yield_vars)|
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
              types << @mod.tuple_of(tuple_types)
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
          arg_type = Type.merge(block_arg_type) || @mod.nil
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

  class Block
    property visited = false
    property scope : Type?
    property vars : MetaVars?
    property after_vars : MetaVars?
    property context : Def | NonGenericModuleType | Nil
    property fun_literal : ASTNode?
    property binder : YieldBlockBinder?

    def break
      @break ||= Var.new("%break")
    end
  end

  class While
    property has_breaks = false
    property break_vars : Array(MetaVars)?
  end

  class Break
    property! target : ASTNode
  end

  class Next
    property! target : ASTNode
  end

  class Return
    property! target : Def
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

  class IsA
    property syntax_replacement : Call?
  end

  module ExpandableNode
    property expanded : ASTNode?
  end

  {% for name in %w(And Or
                   ArrayLiteral HashLiteral RegexLiteral RangeLiteral
                   Case StringInterpolation
                   MacroExpression MacroIf MacroFor MultiAssign
                   SizeOf InstanceSizeOf) %}
    class {{name.id}}
      include ExpandableNode
    end
  {% end %}

  module RuntimeInitializable
    getter runtime_initializers : Array(ASTNode)?

    def add_runtime_initializer(node)
      initializers = @runtime_initializers ||= [] of ASTNode
      initializers << node
    end
  end

  class ClassDef
    include RuntimeInitializable

    property! resolved_type : ClassType
    property created_new_type = false
  end

  class ModuleDef
    property! resolved_type : Type
  end

  class LibDef
    property! resolved_type : LibType
  end

  class Include
    include RuntimeInitializable

    property! resolved_type
  end

  class Extend
    include RuntimeInitializable

    property! resolved_type
  end

  class Def
    include RuntimeInitializable
  end

  class External
    property dead = false
    property used = false
    property call_convention : LLVM::CallConvention?
  end

  class EnumDef
    property! resolved_type : EnumType
    property created_new_type = false
  end

  class Yield
    property expanded : Call?
  end

  class Primitive
    property extra : ASTNode?
  end

  class NilReason
    getter name : String
    getter reason : Symbol
    getter nodes : Array(ASTNode)?
    getter scope : Type?

    def initialize(@name, @reason, @nodes = nil, @scope = nil)
    end
  end

  class Asm
    property ptrof : PointerOf?
  end

  class Assign
    # Whether a class variable assignment needs to be skipped
    # because it was replaced with another initializer
    #
    # ```
    # class Foo
    #   @@x = 1 # This will never execute
    #   @@x = 2
    # end
    # ```
    property? discarded = false
  end

  class TypeDeclaration
    # Whether a class variable assignment needs to be skipped
    # because it was replaced with another initializer
    #
    # ```
    # class Foo
    #   @@x : Int32 = 1 # This will never execute
    #   @@x : Int32 = 2
    # end
    # ```
    property? discarded = false
  end
end
