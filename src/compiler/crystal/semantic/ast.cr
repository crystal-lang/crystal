require "../syntax/ast"
require "simple_hash"

module Crystal
  class ASTNode
    property! type
    property! dependencies
    property freeze_type
    property observers
    property input_observers

    @dirty = false

    def set_type(type : Type)
      type = type.remove_alias_if_simple
      # TODO: this should really be "type.implements?(my_type)"
      if (freeze_type = @freeze_type) && !freeze_type.is_restriction_of_all?(type)
        if !freeze_type.includes_type?(type.program.nil) && type.includes_type?(type.program.nil)
          # This means that an instance variable become nil
          if self.is_a?(MetaInstanceVar) && (nil_reason = self.nil_reason)
            inner = MethodTraceException.new(nil, [] of ASTNode, nil_reason)
          end
        end

        raise "type must be #{freeze_type}, not #{type}", inner, Crystal::FrozenTypeException
      end
      @type = type
    end

    def set_type(type : Nil)
      @type = type
    end

    def type=(type)
      return if type.nil? || @type.same?(type)

      set_type(type)
      notify_observers
      @type
    end

    def map_type(type)
      type
    end

    def bind_to(node : ASTNode)
      bind do |dependencies|
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

    def bind
      dependencies = @dependencies ||= Dependencies.new

      node = yield dependencies

      if dependencies.length == 1
        new_type = node.type?
      else
        new_type = Type.merge dependencies
      end
      return if @type.same? new_type
      return unless new_type

      set_type(map_type(new_type))
      @dirty = true
      propagate
    end

    def unbind_from(nodes : Nil)
      # Nothing to do
    end

    def unbind_from(node : ASTNode)
      @dependencies.try &.delete_if &.same?(node)
      node.remove_observer self
    end

    def unbind_from(nodes : Array(ASTNode))
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
      observers = (@observers ||= [] of ASTNode)
      observers << observer
    end

    def remove_observer(observer)
      @observers.try &.delete_if &.same?(observer)
    end

    def add_input_observer(observer)
      input_observers = (@input_observers ||= [] of Call)
      input_observers << observer
    end

    def remove_input_observer(observer)
      @input_observers.try &.delete_if &.same?(observer)
    end

    def notify_observers
      @observers.try &.each &.update self
      @input_observers.try &.each &.update_input self
      @observers.try &.each &.propagate
      @input_observers.try &.each &.propagate
    end

    def update(from)
      return if @type.same? from.type

      if dependencies.length == 1 || !@type
        new_type = from.type?
      else
        new_type = Type.merge dependencies
      end

      return if @type.same? new_type
      return unless new_type

      set_type(map_type(new_type))
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

    def visibility=(visibility)
    end

    def visibility
      nil
    end
  end

  class Def
    property! :owner
    property! :original_owner
    property :vars
    property :raises

    property closure
    @closure = false

    property :self_closured
    @self_closured = false

    property :previous
    property :next
    property :visibility
    getter :special_vars

    def macro_owner=(@macro_owner)
    end

    def macro_owner
      @macro_owner || @owner
    end

    def add_special_var(name)
      special_vars = @special_vars ||= Set(String).new
      special_vars << name
    end
  end

  class PointerOf
    def map_type(type)
      type.try &.program.pointer_of(type)
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

  class Cast
    property? upcast
    @upcast = false

    def self.apply(node : ASTNode, type : Type)
      cast = Cast.new(node, Var.new("cast", type))
      cast.set_type(type)
      cast
    end

    def update(from = nil)
      to_type = to.type.instance_type

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

          type_var = node_type.virtual_type
        end

        type_var as TypeVar
      end

      begin
        generic_type = instance_type.instantiate(type_vars_types)
      rescue ex
        raise ex.message
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
      self.type = mod.tuple_of types
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
        io << " :: "
        type.to_s(io)
      end
      io << " (nil-if-read)" if nil_if_read
      io << " (closured)" if closured
      io << " (assigned-to)" if assigned_to
    end
  end

  alias MetaVars = SimpleHash(String, MetaVar)

  class MetaInstanceVar < Var
    property :nil_reason
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
    property :visibility
  end

  class Block
    property :visited
    property :scope
    property :vars
    property :after_vars
    property :context
    property :fun_literal

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

  {% for name in %w(ArrayLiteral HashLiteral RegexLiteral MacroExpression MacroIf MacroFor) %}
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
  end

  class Include
    include RuntimeInitializable
  end

  class Extend
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
  end

  class Yield
    property :expanded
  end

  class NilReason
    getter name
    getter reason
    getter nodes
    getter scope

    def initialize(@name, @reason, @nodes = nil, @scope = nil)
    end
  end

  class Arg
    def special_var?
      @name.starts_with? '$'
    end
  end

  class Var
    def special_var?
      @name.starts_with? '$'
    end
  end
end
