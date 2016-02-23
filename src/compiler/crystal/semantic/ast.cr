require "../syntax/ast"
require "simple_hash"

# TODO: 100 is a pretty big number for the number of nested generic instantiations,
# but we might want to implement an algorithm that correctly identifies this
# infinite recursion.
private def generic_type_too_nested?(nest_level)
  nest_level > 100
end

module Crystal
  def self.check_type_allowed_in_generics(node, type, msg)
    return if type.allowed_in_generics?

    type = type.union_types.find { |t| !t.allowed_in_generics? } if type.is_a?(UnionType)
    node.raise "#{msg} yet, use a more specific type"
  end

  class ASTNode
    property! type
    property! dependencies
    property freeze_type
    property observers
    property input_observer

    @dirty = false

    def type
      @type || ::raise "Bug: `#{self}` at #{self.location} has no type"
    end

    def type?
      @type
    end

    def set_type(type : Type)
      type = type.remove_alias_if_simple
      if !type.no_return? && (freeze_type = @freeze_type) && !freeze_type.is_restriction_of_all?(type)
        if !freeze_type.includes_type?(type.program.nil) && type.includes_type?(type.program.nil)
          # This means that an instance variable become nil
          if self.is_a?(MetaInstanceVar) && (nil_reason = self.nil_reason)
            inner = MethodTraceException.new(nil, [] of ASTNode, nil_reason)
          end
        end

        if self.is_a?(MetaInstanceVar)
          raise "instance variable '#{self.name}' of #{self.owner} must be #{freeze_type}, not #{type}", inner, Crystal::FrozenTypeException
        else
          raise "type must be #{freeze_type}, not #{type}", inner, Crystal::FrozenTypeException
        end
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
      return if @type.same? from.type?

      if dependencies.size == 1 || !@type
        new_type = from.type?
      else
        new_type = Type.merge dependencies
      end

      return if @type.same? new_type

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

    def visibility=(visibility : Visibility)
    end

    def visibility
      Visibility::Public
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
          nil_reason = node.nil_reason if node.is_a?(MetaInstanceVar)
          owner_trace << node if node
          visited.add node.object_id
        else
          break
        end
      end

      MethodTraceException.new(owner, owner_trace, nil_reason)
    end
  end

  class Def
    property! :owner
    property! :original_owner
    property :vars
    property :yield_vars

    property :raises
    @raises = false

    property closure
    @closure = false

    property :self_closured
    @self_closured = false

    property :previous
    property :next
    property visibility : Visibility
    @visibility = Visibility::Public

    getter :special_vars

    property :block_nest
    @block_nest = 0

    property? :captured_block
    @captured_block = false

    def macro_owner=(@macro_owner)
    end

    def macro_owner
      @macro_owner || @owner
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
      new_type = new_type as PointerInstanceType
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
    property in_type_args
    @in_type_args = false

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
    property? upcast
    @upcast = false

    def self.apply(node : ASTNode, type : Type)
      cast = Cast.new(node, Var.new("cast", type))
      cast.set_type(type)
      cast
    end

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

  class FunDef
    property! external
  end

  class FunLiteral
    property :force_void
    @force_void = false

    property :expected_return_type

    def update(from = nil)
      return unless self.def.args.all? &.type?
      return unless self.def.type?

      types = self.def.args.map &.type
      return_type = @force_void ? self.def.type.program.void : self.def.type

      expected_return_type = @expected_return_type
      if expected_return_type && !expected_return_type.void? && expected_return_type != return_type
        raise "expected new to return #{expected_return_type}, not #{return_type}"
      end

      types << return_type

      self.type = self.def.type.program.fun_of(types)
    end
  end

  class Generic
    property! instance_type
    property scope
    property in_type_args
    @in_type_args = false

    def update(from = nil)
      type_vars_types = type_vars.map do |node|
        if node.is_a?(Path) && (syntax_replacement = node.syntax_replacement)
          node = syntax_replacement
        end

        case node
        when NumberLiteral
          type_var = node
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
                numeric_value = visitor.interpret_enum_value(value, node_type.program.int32)
                type_var = NumberLiteral.new(numeric_value, :i32)
                type_var.set_type_from(node_type.program.int32, from)
              else
                node.raise "can't use constant #{node} (value = #{value}) as generic type argument, it must be a numeric constant"
              end
            end
          else
            Crystal.check_type_allowed_in_generics(node, node_type, "can't use #{node_type} as generic type argument")
            type_var = node_type.virtual_type
          end
        end

        type_var as TypeVar
      end

      begin
        generic_type = instance_type.instantiate(type_vars_types)
      rescue ex : Crystal::Exception
        raise ex.message
      end

      if generic_type_too_nested?(generic_type.generic_nest)
        raise "generic type too nested: #{generic_type}"
      end

      generic_type = generic_type.metaclass unless @in_type_args
      self.type = generic_type
    end
  end

  class TupleLiteral
    property! :mod

    def update(from = nil)
      return unless elements.all? &.type?

      types = elements.map { |exp| exp.type as TypeVar }
      tuple_type = mod.tuple_of types

      if generic_type_too_nested?(tuple_type.generic_nest)
        raise "tuple type too nested: #{tuple_type}"
      end

      self.type = tuple_type
    end
  end

  class MetaVar < ASTNode
    property :name

    # True if we need to mark this variable as nilable
    # if this variable is read.
    property :nil_if_read

    # This is the context of the variable: who allocates it.
    # It can either be the Program (for top level variables),
    # a Def or a Block.
    property :context

    # A variable is closured if it's used in a FunLiteral context
    # where it wasn't created.
    property :closured

    # Is this metavar assigned a value?
    property :assigned_to

    def initialize(@name, @type = nil)
      @nil_if_read = false
      @closured = false
      @assigned_to = false
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
    end
  end

  alias MetaVars = Hash(String, MetaVar)

  class MetaInstanceVar < Var
    property :nil_reason
    property! :owner
  end

  class ClassVar
    property! owner
    property! var
    property! class_scope

    @class_scope = false
  end

  class Path
    property target_const
    property syntax_replacement
  end

  class Call
    property :before_vars
    property visibility : Visibility
    @visibility = Visibility::Public
  end

  class Macro
    property visibility : Visibility
    @visibility = Visibility::Public
  end

  class Block
    property :visited
    property :scope
    property :vars
    property :after_vars
    property :context
    property :fun_literal
    property :call

    @visited = false

    def break
      @break ||= Var.new("%break")
    end
  end

  class While
    property :has_breaks
    property :break_vars

    @has_breaks = false
  end

  class Break
    property! target
  end

  class Next
    property! target
  end

  class Return
    property! target
  end

  class FunPointer
    property! :call

    def map_type(type)
      return nil unless call.type?

      arg_types = call.args.map &.type
      arg_types.push call.type

      call.type.program.fun_of(arg_types)
    end
  end

  class IsA
    property :syntax_replacement
  end

  module ExpandableNode
    property :expanded
  end

  {% for name in %w(And Or
                   ArrayLiteral HashLiteral RegexLiteral RangeLiteral
                   Case StringInterpolation
                   MacroExpression MacroIf MacroFor) %}
    class {{name.id}}
      include ExpandableNode
    end
  {% end %}

  module RuntimeInitializable
    getter runtime_initializers

    def add_runtime_initializer(node)
      initializers = @runtime_initializers ||= [] of ASTNode
      initializers << node
    end
  end

  class ClassDef
    include RuntimeInitializable

    property! resolved_type
    property created_new_type
    @created_new_type = false
  end

  class ModuleDef
    property! resolved_type
  end

  class LibDef
    property! resolved_type
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
    property :dead
    @dead = false

    property :used
    @used = false

    property :call_convention
  end

  class EnumDef
    property enum_type
    property! resolved_type
  end

  class Yield
    property :expanded
  end

  class Primitive
    property :extra
  end

  class NilReason
    getter name
    getter reason
    getter nodes
    getter scope

    def initialize(@name, @reason, @nodes = nil, @scope = nil)
    end
  end

  {% for name in %w(Arg Var MetaVar) %}
    class {{name.id}}
      def special_var?
        @name.starts_with? '$'
      end
    end
  {% end %}

  class Asm
    property ptrof
  end
end
