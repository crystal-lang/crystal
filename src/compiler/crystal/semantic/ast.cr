require "../syntax/ast"

module Crystal
  def self.check_type_allowed_in_generics(node, type, msg)
    return if type.allowed_in_generics?

    type = type.union_types.find { |t| !t.allowed_in_generics? } if type.is_a?(UnionType)
    node.raise "#{msg} yet, use a more specific type"
  end

  class ASTNode
    def raise(message, inner = nil, exception_type = Crystal::TypeException)
      ::raise exception_type.for_node(self, message, inner)
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
    property extra : ASTNode?

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

  # Fictitious node to represent a type restriction
  #
  # It is used for type restrection of method arguments.
  class TypeRestriction < ASTNode
    getter obj
    getter to

    def initialize(@obj : ASTNode, @to : ASTNode)
    end

    def clone_without_location
      TypeRestriction.new @obj.clone, @to.clone
    end

    def_equals_and_hash obj, to
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
    property previous : DefWithMetadata?
    property next : Def?
    getter special_vars : Set(String)?
    property block_nest = 0
    getter? raises = false
    property? closure = false
    property? self_closured = false
    property? captured_block = false

    # `true` if this def has the `@[NoInline]` attribute
    property? no_inline = false

    # `true` if this def has the `@[AlwaysInline]` attribute
    property? always_inline = false

    # `true` if this def has the `@[ReturnsTwice]` attribute
    property? returns_twice = false

    # `true` if this def has the `@[Naked]` attribute
    property? naked = false

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

    # Returns the minimum and maximum number of arguments that must
    # be passed to this method.
    def min_max_args_sizes
      max_size = args.size
      default_value_index = args.index(&.default_value)
      min_size = default_value_index || max_size
      splat_index = self.splat_index
      if splat_index
        if args[splat_index].name.empty?
          min_size = {default_value_index || splat_index, splat_index}.min
          max_size = splat_index
        else
          min_size -= 1 unless default_value_index && default_value_index < splat_index
          max_size = Int32::MAX
        end
      end
      {min_size, max_size}
    end

    def clone_without_location
      a_def = previous_def
      a_def.previous = previous
      a_def.raises = raises?
      a_def.no_inline = no_inline?
      a_def.always_inline = always_inline?
      a_def.returns_twice = returns_twice?
      a_def.naked = naked?
      a_def.new = new?
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

    def free_var?(node : Path)
      free_vars = @free_vars
      return false unless free_vars

      !node.global? && node.names.size == 1 && free_vars.includes?(node.names.first)
    end

    def free_var?(any)
      false
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

    def matches?(call_args, named_args)
      call_args_size = call_args.size
      my_args_size = args.size
      min_args_size = args.index(&.default_value) || my_args_size
      max_args_size = my_args_size
      splat_index = self.splat_index

      if splat_index
        if args[splat_index].external_name.empty?
          min_args_size = max_args_size = splat_index
        else
          min_args_size -= 1
          max_args_size = Int32::MAX
        end
      end

      # If there are arguments past the splat index and no named args, there's no match,
      # unless all args past it have default values
      if splat_index && my_args_size > splat_index + 1 && !named_args
        unless (splat_index + 1...args.size).all? { |i| args[i].default_value }
          return false
        end
      end

      # If there are more positional arguments than those required, there's no match
      # (if there's less they might be matched with named arguments)
      if call_args_size > max_args_size
        return false
      end

      # If there are named args we must check that all mandatory args
      # are covered by positional arguments or named arguments.
      if named_args
        mandatory_args = BitArray.new(my_args_size)
      elsif call_args_size < min_args_size
        # Otherwise, they must be matched by positional arguments
        return false
      end

      self.match(call_args) do |my_arg, my_arg_index, call_arg, call_arg_index|
        mandatory_args[my_arg_index] = true if mandatory_args
      end

      # Check named args
      named_args.try &.each do |named_arg|
        found_index = args.index { |arg| arg.external_name == named_arg.name }
        if found_index
          # A named arg can't target the splat index
          if found_index == splat_index
            return false
          end

          # Check whether the named arg refers to an argument that was already specified
          if mandatory_args
            if mandatory_args[found_index]
              return false
            end

            mandatory_args[found_index] = true
          else
            if found_index < call_args_size
              return false
            end
          end
        else
          # A double splat matches all named args
          next if double_splat

          return false
        end
      end

      # Check that all mandatory args were specified
      # (either with positional arguments or with named arguments)
      if mandatory_args
        self.args.each_with_index do |arg, index|
          if index != splat_index && !arg.default_value && !mandatory_args[index]
            return false
          end
        end
      end

      true
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

  class FunDef
    property! external : External
  end

  class If
    # This is set to `true` for an `If` that was created from an `&&` expression.
    property? and = false

    # This is set to `true` for an `If` that was created from an `||` expression.
    property? or = false

    # This is set to `true` when the compiler is sure that the condition is truthy
    property? truthy = false

    # This is set to `true` when the compiler is sure that the condition is falsey
    property? falsey = false

    def clone_without_location
      a_if = previous_def
      a_if.and = and?
      a_if.or = or?
      a_if
    end
  end

  class MetaVar < ASTNode
    include SpecialVar

    property name : String

    # This is the context of the variable: who allocates it.
    # It can either be the Program (for top level variables),
    # a Def or a Block.
    property context : ASTNode | NonGenericModuleType | Nil

    # True if we need to mark this variable as nilable
    # if this variable is read.
    property? nil_if_read = false

    # A variable is closured if it's used in a ProcLiteral context
    # where it wasn't created.
    property? closured = false

    # Is this metavar assigned a value?
    property? assigned_to = false

    def initialize(@name : String, @type : Type? = nil)
    end

    # True if this variable belongs to the given context
    # but must be allocated in a closure.
    def closure_in?(context)
      closured? && belongs_to?(context)
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
      io << " (nil-if-read)" if nil_if_read?
      io << " (closured)" if closured?
      io << " (assigned-to)" if assigned_to?
      io << " (object id: #{object_id})"
    end

    def pretty_print(pp)
      pp.text inspect
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

    # The (optional) initial value of a class variable
    property initializer : ClassVarInitializer?

    # Is this variable thread local? Only applicable
    # to global and class variables.
    property? thread_local = false

    # Is this variable "unsafe" (no need to check if it was initialized)?
    property? uninitialized = false

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

  class Block
    property scope : Type?
    property vars : MetaVars?
    property after_vars : MetaVars?
    property context : Def | NonGenericModuleType | Nil
    property fun_literal : ASTNode?
    property? visited = false

    getter(:break) { Var.new("%break") }
  end

  class While
    property break_vars : Array(MetaVars)?

    def has_breaks?
      !!@break_vars
    end
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
                   SizeOf InstanceSizeOf Global Require Select) %}
    class {{name.id}}
      include ExpandableNode
    end
  {% end %}

  class ClassDef
    property! resolved_type : ClassType
  end

  class ModuleDef
    property! resolved_type : ModuleType
  end

  class LibDef
    property! resolved_type : LibType
  end

  class CStructOrUnionDef
    property! resolved_type : NonGenericClassType
  end

  class Alias
    property! resolved_type : AliasType
  end

  class External < Def
    property real_name : String
    property! fun_def : FunDef
    property call_convention : LLVM::CallConvention?

    property? dead = false
    property? used = false
    property? varargs = false

    # An External is also used to represent external variables
    # such as libc's `$errno`, which can be annotated with
    # `@[ThreadLocal]`. This property is `true` in that case.
    property? thread_local = false

    def initialize(name : String, args : Array(Arg), body, @real_name : String)
      super(name, args, body, nil, nil, nil)
    end

    def mangled_name(program, obj_type)
      real_name
    end

    def compatible_with?(other)
      return false if args.size != other.args.size
      return false if varargs? != other.varargs?

      args.each_with_index do |arg, i|
        return false if arg.type != other.args[i].type
      end

      type == other.type
    end

    def_hash @real_name, @varargs, @fun_def
  end

  class EnumDef
    property! resolved_type : EnumType
  end

  class Yield
    property expanded : Call?
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

  # Fictitious node that means "all these nodes come from this file"
  class FileNode < ASTNode
    property node : ASTNode
    property filename : String

    def initialize(@node : ASTNode, @filename : String)
    end

    def accept_children(visitor)
      @node.accept visitor
    end

    def clone_without_location
      self
    end

    def_equals_and_hash node, filename
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

  # Fictitious node to represent an id inside a macro
  class MacroId < ASTNode
    property value : String

    def initialize(@value)
    end

    def to_macro_id
      @value
    end

    def clone_without_location
      self
    end

    def_equals_and_hash value
  end
end
