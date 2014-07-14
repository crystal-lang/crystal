require "../ast"

module Crystal
  class ASTNode
    property! type
    property! dependencies
    property freeze_type
    property observers
    property input_observers

    @freeze_type = false
    @dirty = false

    def out?
      false
    end

    def set_type(type : Type)
      type = type.remove_alias_if_simple
      # TODO: this should really be "type.implements?(my_type)"
      if @freeze_type && (my_type = @type) && !my_type.is_restriction_of_all?(type)
        raise "type must be #{my_type}, not #{type}", nil, Crystal::FrozenTypeException
      end
      @type = type
    end

    def set_type(type : Nil)
      @type = type
    end

    def type=(type)
      return if type.nil? || @type.object_id == type.object_id

      set_type(type)
      notify_observers
      @type
    end

    def map_type(type)
      type
    end

    def bind_to(node : ASTNode)
      bind_to [node] of ASTNode
    end

    def bind_to(nodes : Array)
      dependencies = @dependencies ||= [] of ASTNode
      dependencies.concat nodes
      nodes.each &.add_observer self

      if dependencies.length == 1
        new_type = nodes[0].type?
      else
        new_type = Type.merge dependencies
      end
      return if @type.object_id == new_type.object_id
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

    def unbind_from(nodes : Array)
      nodes.each do |node|
        unbind_from node
      end
    end

    def add_observer(observer)
      observers = (@observers ||= [] of ASTNode)
      observers << observer
    end

    def add_input_observer(observer)
      input_observers = (@input_observers ||= [] of Call)
      input_observers << observer
    end

    def remove_observer(observer)
      @observers.try &.delete_if &.same?(observer)
    end

    def notify_observers
      @observers.try &.each do |observer|
        observer.update self
      end

      @input_observers.try &.each do |observer|
        observer.update_input self
      end

      @observers.try &.each do |observer|
        observer.propagate
      end

      @input_observers.try &.each do |observer|
        observer.propagate
      end
    end

    def update(from)
      return if @type.object_id == from.type.object_id

      if dependencies.length == 1 || !@type
        new_type = from.type?
      else
        new_type = Type.merge dependencies
      end

      return if @type.object_id == new_type.object_id
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
    def self.apply(node : ASTNode, type : Type)
      cast = Cast.new(node, Var.new("cast", type))
      cast.set_type(type)
      cast
    end

    def update(from = nil)
      obj_type = obj.type?
      return unless obj_type

      to_type = to.type.instance_type

      if obj_type.pointer? || to_type.pointer?
        self.type = to_type
      else
        self.type = obj_type.filter_by(to_type)
      end
    end
  end

  class FunLiteral
    property :force_void
    @force_void = false

    property :expected_return_type

    def update(from = nil)
      return unless self.def.args.all? &.type?
      return unless self.def.type?

      types = self.def.args.map &.type
      if @force_void
        return_type = self.def.type.program.void
      else
        return_type = self.def.type
      end

      expected_return_type = @expected_return_type
      if expected_return_type && !expected_return_type.void? && expected_return_type != return_type
        raise "expected new to return #{expected_return_type}, not #{return_type}"
      end

      types.push return_type

      self.type = self.def.type.program.fun_of(types)
    end
  end

  class Generic
    property! instance_type
    property in_type_args
    @in_type_args = false

    def update(from = nil)
      type_vars_types = [] of Type | ASTNode
      type_vars.each do |node|
        case node
        when NumberLiteral
          type_vars_types << node
        else
          node_type = node.type?
          self.raise "can't deduce generic type in recursive method" unless node_type
          type_vars_types << node_type.hierarchify
        end
      end

      generic_type = instance_type.instantiate(type_vars_types)
      generic_type = generic_type.metaclass unless @in_type_args
      self.type = generic_type
    end
  end

  class TupleLiteral
    def update(from = nil)
      return unless elements.all? &.type?

      types = [] of Type | ASTNode
      elements.each { |exp| types << exp.type }
      self.type = elements.first.type.program.tuple_of types
    end
  end

  class Def
    property :owner
    property :vars
    property :raises

    property closure
    @closure = false

    property :self_closured
    @self_closured = false

    def macro_owner=(@macro_owner)
    end

    def macro_owner
      @macro_owner || @owner
    end

    def has_default_arguments?
      args.length > 0 && args.last.default_value
    end

    def expand_default_arguments
      self_def = clone
      self_def.instance_vars = instance_vars
      self_def.args.each { |arg| arg.default_value = nil }

      retain_body = yields || args.any? { |arg| arg.default_value && arg.restriction }

      expansions = [self_def]

      i = args.length - 1
      while i >= 0 && (arg_default_value = (arg = args[i]).default_value)
        expansion = Def.new(name, self_def.args[0 ... i].map(&.clone), nil, receiver.clone, self_def.block_arg.clone, self_def.return_type.clone, self_def.yields)
        expansion.instance_vars = instance_vars
        expansion.calls_super = calls_super
        expansion.uses_block_arg = uses_block_arg
        expansion.yields = yields

        if retain_body
          new_body = [] of ASTNode
          args[i .. -1].each do |arg2|
            arg2_default_value = arg2.default_value
            raise "Bug: arg2_default_value should not have been nil" unless arg2_default_value

            new_body << Assign.new(Var.new(arg2.name), arg2_default_value)
          end
          new_body.push body.clone
          expansion.body = Expressions.new(new_body)
        else
          new_args = [] of ASTNode
          self_def.args[0 ... i].each do |arg2|
            new_args.push Var.new(arg2.name)
          end
          raise "Bug: #{arg_default_value} should not have been nil" unless arg_default_value

          new_args.push arg_default_value

          expansion.body = Call.new(nil, name, new_args)
        end

        expansions << expansion
        i -= 1
      end

      expansions
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

  alias MetaVars = Hash(String, MetaVar)

  class Var
    def out?
      out
    end
  end

  class InstanceVar
    def out?
      out
    end
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

  class Arg
    def self.new_with_type(name, type)
      arg = new(name)
      arg.set_type(type)
      arg
    end

    def self.new_with_restriction(name, restriction)
      arg = Arg.new(name)
      arg.restriction = restriction
      arg
    end
  end

  class Call
    property :before_vars
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

  {% for name in %w(ArrayLiteral HashLiteral MacroExpression MacroIf MacroFor) %}
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
end
