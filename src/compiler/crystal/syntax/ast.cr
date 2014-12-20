module Crystal
  # Base class for nodes in the grammar.
  abstract class ASTNode
    property location

    def at(@location : Location?)
      self
    end

    def at(node : ASTNode)
      at node.location
    end

    def clone
      clone = clone_without_location
      clone.location = location
      clone.attributes = attributes
      clone
    end

    def attributes
    end

    def attributes=(attributes)
    end

    def doc
    end

    def doc=(doc)
    end

    def has_attribute?(name)
      Attribute.any?(attributes, name)
    end

    def name_column_number
      @location.try(&.column_number) || 0
    end

    def name_length
      0
    end

    def nop?
      false
    end

    def true_literal?
      false
    end

    def false_literal?
      false
    end

    macro def class_desc : String
      {{@class_name.split("::").last}}
    end
  end

  class Nop < ASTNode
    def nop?
      true
    end

    def clone_without_location
      Nop.new
    end

    def_equals_and_hash
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    property :expressions

    def self.from(obj : Nil)
      Nop.new
    end

    def self.from(obj : Array)
      case obj.length
      when 0
        Nop.new
      when 1
        obj.first
      else
        new obj
      end
    end

    def self.from(obj : ASTNode)
      obj
    end

    def initialize(@expressions = [] of ASTNode)
    end

    def empty?
      @expressions.empty?
    end

    def [](i)
      @expressions[i]
    end

    def last
      @expressions.last
    end

    def accept_children(visitor)
      @expressions.each &.accept visitor
    end

    def clone_without_location
      Expressions.new(@expressions.clone)
    end

    def_equals_and_hash expressions
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def clone_without_location
      self
    end

    def_equals_and_hash
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    property :value

    def initialize(@value)
    end

    def false_literal?
      !value
    end

    def true_literal?
      value
    end

    def clone_without_location
      BoolLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  # Any number literal.
  # kind stores a symbol indicating which type is it: i32, u16, f32, f64, etc.
  class NumberLiteral < ASTNode
    property :value
    property :kind

    def initialize(@value : String, @kind = :i32)
    end

    def initialize(value : Number, @kind = :i32)
      @value = value.to_s
    end

    def has_sign?
      @value[0] == '+' || @value[0] == '-'
    end

    def clone_without_location
      NumberLiteral.new(@value, @kind)
    end

    def_equals value.to_f64, kind
    def_hash value, kind
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    property :value

    def initialize(@value)
    end

    def clone_without_location
      CharLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  class StringLiteral < ASTNode
    property :value

    def initialize(@value)
    end

    def clone_without_location
      StringLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  class StringInterpolation < ASTNode
    property :expressions

    def initialize(@expressions)
    end

    def accept_children(visitor)
      @expressions.each &.accept visitor
    end

    def clone_without_location
      StringInterpolation.new(@expressions.clone)
    end

    def_equals_and_hash expressions
  end

  class SymbolLiteral < ASTNode
    property :value

    def initialize(@value)
    end

    def clone_without_location
      SymbolLiteral.new(@value)
    end

    def_equals_and_hash value
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    property :elements
    property :of
    property :name

    def initialize(@elements = [] of ASTNode, @of = nil, @name = nil)
    end

    def self.map(values)
      new(values.map { |value| (yield value) as ASTNode })
    end

    def accept_children(visitor)
      @name.try &.accept visitor
      elements.each &.accept visitor
      @of.try &.accept visitor
    end

    def clone_without_location
      ArrayLiteral.new(@elements.clone, @of.clone, @name.clone)
    end

    def_equals_and_hash @elements, @of, @name
  end

  class HashLiteral < ASTNode
    property :entries
    property :of
    property :name

    def initialize(@entries = [] of Entry, @of = nil, @name = nil)
    end

    def accept_children(visitor)
      @name.try &.accept visitor
      @entries.each do |entry|
        entry.key.accept visitor
        entry.value.accept visitor
      end
      if of = @of
        of.key.accept visitor
        of.value.accept visitor
      end
    end

    def clone_without_location
      HashLiteral.new(@entries.clone, @of.clone, @name.clone)
    end

    def_equals_and_hash @entries, @of, @name

    record Entry, key, value
  end

  class RangeLiteral < ASTNode
    property :from
    property :to
    property :exclusive

    def initialize(@from, @to, @exclusive)
    end

    def accept_children(visitor)
      @from.accept visitor
      @to.accept visitor
    end

    def clone_without_location
      RangeLiteral.new(@from.clone, @to.clone, @exclusive.clone)
    end

    def_equals_and_hash @from, @to, @exclusive
  end

  class RegexLiteral < ASTNode
    property :value
    property :modifiers

    def initialize(@value, @modifiers = 0)
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def clone_without_location
      RegexLiteral.new(@value, @modifiers)
    end

    def_equals_and_hash @value, @modifiers
  end

  class TupleLiteral < ASTNode
    property :elements

    def initialize(@elements)
    end

    def accept_children(visitor)
      elements.each &.accept visitor
    end

    def clone_without_location
      TupleLiteral.new(elements.clone)
    end

    def_equals_and_hash elements
  end

  # A local variable or block argument.
  class Var < ASTNode
    property :name
    property :attributes

    def initialize(@name, @type = nil)
    end

    def add_attributes(attributes)
      if attributes
        if my_attributes = @attributes
          my_attributes.concat attributes
        else
          @attributes = attributes.dup
        end
      end
    end

    def name_length
      name.length
    end

    def clone_without_location
      Var.new(@name)
    end

    def_equals name, type?
    def_hash name
  end

  # A code block.
  #
  #     'do' [ '|' arg [ ',' arg ]* '|' ]
  #       body
  #     'end'
  #   |
  #     '{' [ '|' arg [ ',' arg ]* '|' ] body '}'
  #
  class Block < ASTNode
    property :args
    property :body

    def initialize(@args = [] of Var, body = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      Block.new(@args.clone, @body.clone)
    end

    def_equals_and_hash args, body
  end

  # A method call.
  #
  #     [ obj '.' ] name '(' ')' [ block ]
  #   |
  #     [ obj '.' ] name '(' arg [ ',' arg ]* ')' [ block]
  #   |
  #     [ obj '.' ] name arg [ ',' arg ]* [ block ]
  #   |
  #     arg name arg
  #
  # The last syntax is for infix operators, and name will be
  # the symbol of that operator instead of a string.
  #
  class Call < ASTNode
    @global = false
    @has_parenthesis = false

    property :obj
    property :name
    property :args
    property :block
    property :block_arg
    property :named_args
    property :global
    property :name_column_number
    property :has_parenthesis
    property :name_length
    property :doc

    def initialize(@obj, @name, @args = [] of ASTNode, @block = nil, @block_arg = nil, @named_args = nil, @global = false, @name_column_number = 0, @has_parenthesis = false)
      @name_length = nil
    end

    def self.new(obj, name, arg : ASTNode)
      new obj, name, [arg] of ASTNode
    end

    def self.new(obj, name, arg1 : ASTNode, arg2 : ASTNode)
      new obj, name, [arg1, arg2] of ASTNode
    end

    def self.global(name, arg : ASTNode)
      new nil, name, [arg] of ASTNode, global: true
    end

    def self.global(name, arg1 : ASTNode, arg2 : ASTNode)
      new nil, name, [arg1, arg2] of ASTNode, global: true
    end

    def name_length
      @name_length ||= name.to_s.ends_with?('=') || name.to_s.ends_with?('@') ? name.length - 1 : name.length
    end

    def accept_children(visitor)
      @obj.try &.accept visitor
      @args.each &.accept visitor
      @named_args.try &.each &.accept visitor
      @block_arg.try &.accept visitor
      @block.try &.accept visitor
    end

    def clone_without_location
      clone = Call.new(@obj.clone, @name, @args.clone, @block.clone, @block_arg.clone, @named_args.clone, @global, @name_column_number, @has_parenthesis)
      clone.name_length = name_length
      clone.is_expansion = is_expansion?
      clone
    end

    def_equals_and_hash obj, name, args, block, block_arg, named_args, global
  end

  class NamedArgument < ASTNode
    property :name
    property :value

    def initialize(@name, @value)
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def clone_without_location
      NamedArgument.new(name, value.clone)
    end

    def_equals_and_hash name, value
  end

  # An if expression.
  #
  #     'if' cond
  #       then
  #     [
  #     'else'
  #       else
  #     ]
  #     'end'
  #
  # An if elsif end is parsed as an If whose
  # else is another If.
  class If < ASTNode
    property :cond
    property :then
    property :else
    property :binary

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      a_if = If.new(@cond.clone, @then.clone, @else.clone)
      a_if.binary = binary
      a_if
    end

    def_equals_and_hash @cond, @then, @else
  end

  class Unless < ASTNode
    property :cond
    property :then
    property :else

    def initialize(@cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      Unless.new(@cond.clone, @then.clone, @else.clone)
    end

    def_equals_and_hash @cond, @then, @else
  end

  # An ifdef expression.
  #
  #     'ifdef' cond
  #       then
  #     [
  #     'else'
  #       else
  #     ]
  #     'end'
  #
  # An if elsif end is parsed as an If whose
  # else is another If.
  class IfDef < ASTNode
    property :cond
    property :then
    property :else

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      IfDef.new(@cond.clone, @then.clone, @else.clone)
    end

    def_equals_and_hash @cond, @then, @else
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < ASTNode
    property :target
    property :value
    property :doc

    def initialize(@target, @value)
    end

    def accept_children(visitor)
      @target.accept visitor
      @value.accept visitor
    end

    def clone_without_location
      Assign.new(@target.clone, @value.clone)
    end

    def_equals_and_hash @target, @value
  end

  # Assign expression.
  #
  #     target [',' target]+ '=' value [',' value]*
  #
  class MultiAssign < ASTNode
    property :targets
    property :values

    def initialize(@targets, @values)
    end

    def accept_children(visitor)
      @targets.each &.accept visitor
      @values.each &.accept visitor
    end

    def ==(other : self)
      other.targets == targets && other.values == values
    end

    def clone_without_location
      MultiAssign.new(@targets.clone, @values.clone)
    end

    def_hash @targets, @values
  end

  # An instance variable.
  class InstanceVar < ASTNode
    property :name

    def initialize(@name)
    end

    def name_length
      name.length
    end

    def clone_without_location
      InstanceVar.new(@name)
    end

    def_equals_and_hash name
  end

  class ReadInstanceVar < ASTNode
    property :obj
    property :name

    def initialize(@obj, @name)
    end

    def accept_children(visitor)
      @obj.accept visitor
    end

    def clone_without_location
      ReadInstanceVar.new(@obj.clone, @name)
    end

    def_equals_and_hash @obj, @name
  end

  class ClassVar < ASTNode
    property :name
    property :attributes

    def initialize(@name)
    end

    def clone_without_location
      ClassVar.new(@name)
    end

    def_equals_and_hash name
  end

  # A global variable.
  class Global < ASTNode
    property :name
    property :attributes

    def initialize(@name)
    end

    def name_length
      name.length
    end

    def clone_without_location
      Global.new(@name)
    end

    def_equals_and_hash name
  end

  abstract class BinaryOp < ASTNode
    property :left
    property :right

    def initialize(@left, @right)
    end

    def accept_children(visitor)
      @left.accept visitor
      @right.accept visitor
    end

    def_equals_and_hash left, right
  end

  # Expressions and.
  #
  #     expression '&&' expression
  #
  class And < BinaryOp
    def clone_without_location
      And.new(@left.clone, @right.clone)
    end
  end

  # Expressions or.
  #
  #     expression '||' expression
  #
  class Or < BinaryOp
    def clone_without_location
      Or.new(@left.clone, @right.clone)
    end
  end

  # A def argument.
  class Arg < ASTNode
    property :name
    property :default_value
    property :restriction
    property :doc

    def initialize(@name, @default_value = nil, @restriction = nil, @type = nil)
    end

    def accept_children(visitor)
      @default_value.try &.accept visitor
      @restriction.try &.accept visitor
    end

    def name_length
      name.length
    end

    def clone_without_location
      arg = Arg.new @name, @default_value.clone, @restriction.clone

      # An arg's type can sometimes be used as a restriction,
      # and must be preserved when cloned
      arg.set_type @type

      arg
    end

    def_equals_and_hash name, default_value, restriction
  end

  class Fun < ASTNode
    property :inputs
    property :output

    def initialize(@inputs = nil, @output = nil)
    end

    def accept_children(visitor)
      @inputs.try &.each &.accept visitor
      @output.try &.accept visitor
    end

    def clone_without_location
      Fun.new(@inputs.clone, @output.clone)
    end

    def_equals_and_hash inputs, output
  end

  class BlockArg < ASTNode
    property :name
    property :fun

    def initialize(@name, @fun = Fun.new)
    end

    def accept_children(visitor)
      @fun.try &.accept visitor
    end

    def name_length
      name.length
    end

    def clone_without_location
      BlockArg.new(@name, @fun.clone)
    end

    def_equals_and_hash @name, @fun
  end

  # A method definition.
  #
  #     [ receiver '.' ] 'def' name
  #       body
  #     'end'
  #   |
  #     [ receiver '.' ] 'def' name '(' [ arg [ ',' arg ]* ] ')'
  #       body
  #     'end'
  #   |
  #     [ receiver '.' ] 'def' name arg [ ',' arg ]*
  #       body
  #     'end'
  #
  class Def < ASTNode
    property :receiver
    property :name
    property :args
    property :body
    property :block_arg
    property :return_type
    property :yields
    property :instance_vars
    property :calls_super
    property :calls_initialize
    property :uses_block_arg
    property :name_column_number
    property :abstract
    property :attributes
    property :splat_index
    property :doc

    def initialize(@name, @args = [] of Arg, body = nil, @receiver = nil, @block_arg = nil, @return_type = nil, @yields = nil, @abstract = false, @splat_index = nil)
      @body = Expressions.from body
      @calls_super = false
      @calls_initialize = false
      @uses_block_arg = false
      @raises = false
      @name_column_number = 0
    end

    def accept_children(visitor)
      @receiver.try &.accept visitor
      @args.each &.accept visitor
      @block_arg.try &.accept visitor
      @return_type.try &.accept visitor
      @body.accept visitor
    end

    def name_length
      name.length
    end

    def min_max_args_lengths
      max_length = args.length
      default_value_index = args.index(&.default_value)
      min_length = default_value_index || max_length
      if splat_index
        min_length -= 1 unless default_value_index
        max_length = Int32::MAX
      end
      {min_length, max_length}
    end

    def has_default_arguments?
      args.length > 0 && args.last.default_value
    end

    def clone_without_location
      a_def = Def.new(@name, @args.clone, @body.clone, @receiver.clone, @block_arg.clone, @return_type.clone, @yields, @abstract, @splat_index)
      a_def.instance_vars = instance_vars
      a_def.calls_super = calls_super
      a_def.calls_initialize = calls_initialize
      a_def.uses_block_arg = uses_block_arg
      a_def.name_column_number = name_column_number
      a_def.previous = previous
      a_def.raises = raises
      a_def
    end

    def_equals_and_hash @name, @args, @body, @receiver, @block_arg, @return_type, @yields, @abstract, @splat_index
  end

  class Macro < ASTNode
    property :name
    property :args
    property :body
    property :block_arg
    property :name_column_number
    property :splat_index
    property :doc

    def initialize(@name, @args = [] of ASTNode, @body = Nop.new, @block_arg = nil, @splat_index = nil)
      @name_column_number = 0
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @body.accept visitor
      @block_arg.try &.accept visitor
    end

    def name_length
      name.length
    end

    def matches?(args_length, named_args)
      my_args_length = args.length
      min_args_length = args.index(&.default_value) || my_args_length
      max_args_length = my_args_length
      if splat_index
        min_args_length -= 1
        max_args_length = Int32::MAX
      end

      unless min_args_length <= args_length <= max_args_length
        return false
      end

      named_args.try &.each do |named_arg|
        index = args.index { |arg| arg.name == named_arg.name }
        if index
          if index < args_length
            return false
          end
        else
          return false
        end
      end

      true
    end

    def clone_without_location
      Macro.new(@name, @args.clone, @body.clone, @block_arg.clone, @splat_index)
    end

    def_equals_and_hash @name, @args, @body, @block_arg, @splat_index
  end

  abstract class UnaryExpression < ASTNode
    property :exp

    def initialize(@exp)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def_equals_and_hash exp
  end

  # Used only for flags
  class Not < UnaryExpression
    def clone_without_location
      Not.new(@exp.clone)
    end
  end

  class PointerOf < UnaryExpression
    def clone_without_location
      PointerOf.new(@exp.clone)
    end
  end

  class SizeOf < UnaryExpression
    def clone_without_location
      SizeOf.new(@exp.clone)
    end
  end

  class InstanceSizeOf < UnaryExpression
    def clone_without_location
      InstanceSizeOf.new(@exp.clone)
    end
  end

  class Out < UnaryExpression
    def clone_without_location
      Out.new(@exp.clone)
    end
  end

  class VisibilityModifier < ASTNode
    property modifier
    property exp
    property doc

    def initialize(@modifier, @exp)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def clone_without_location
      VisibilityModifier.new(@modifier, @exp.clone)
    end

    def_equals_and_hash modifier, exp
  end

  class IsA < ASTNode
    property :obj
    property :const

    def initialize(@obj, @const)
    end

    def accept_children(visitor)
      @obj.accept visitor
      @const.accept visitor
    end

    def clone_without_location
      IsA.new(@obj.clone, @const.clone)
    end

    def_equals_and_hash @obj, @const
  end

  class RespondsTo < ASTNode
    property :obj
    property :name

    def initialize(@obj, @name)
    end

    def accept_children(visitor)
      obj.accept visitor
      name.accept visitor
    end

    def clone_without_location
      RespondsTo.new(@obj.clone, @name)
    end

    def_equals_and_hash @obj, @name
  end

  class Require < ASTNode
    property :string

    def initialize(@string)
    end

    def clone_without_location
      Require.new(@string)
    end

    def_equals_and_hash string
  end

  class When < ASTNode
    property :conds
    property :body

    def initialize(@conds, body = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @conds.each &.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      When.new(@conds.clone, @body.clone)
    end

    def_equals_and_hash @conds, @body
  end

  class Case < ASTNode
    property :cond
    property :whens
    property :else

    def initialize(@cond, @whens, @else = nil)
    end

    def accept_children(visitor)
      @whens.each &.accept visitor
      @else.try &.accept visitor
    end

    def clone_without_location
      Case.new(@cond.clone, @whens.clone, @else.clone)
    end

    def_equals_and_hash @cond, @whens, @else
  end

  # Node that represents an implicit obj in:
  #
  #     case foo
  #     when .bar? # this is a call with an implicit obj
  #     end
  class ImplicitObj < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      self
    end

    def hash
      0
    end
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Path < ASTNode
    property :names
    property :global
    property :name_length

    def initialize(@names : Array, @global = false)
      @name_length = 0
    end

    def self.new(name : String, global = false)
      new [name], global
    end

    def self.global(names)
      new names, true
    end

    def clone_without_location
      ident = Path.new(@names.clone, @global)
      ident.name_length = name_length
      ident
    end

    def_equals_and_hash @names, @global
  end

  # Class definition:
  #
  #     'class' name [ '<' superclass ]
  #       body
  #     'end'
  #
  class ClassDef < ASTNode
    property :name
    property :body
    property :superclass
    property :type_vars
    property :abstract
    property :struct
    property :name_column_number
    property :attributes
    property :doc

    def initialize(@name, body = nil, @superclass = nil, @type_vars = nil, @abstract = false, @struct = false, @name_column_number = 0)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @superclass.try &.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      ClassDef.new(@name, @body.clone, @superclass.clone, @type_vars.clone, @abstract, @struct, @name_column_number)
    end

    def_equals_and_hash @name, @body, @superclass, @type_vars, @abstract, @struct
  end

  # Module definition:
  #
  #     'module' name
  #       body
  #     'end'
  #
  class ModuleDef < ASTNode
    property :name
    property :body
    property :type_vars
    property :name_column_number
    property :doc

    def initialize(@name, body = nil, @type_vars = nil, @name_column_number = 0)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def clone_without_location
      ModuleDef.new(@name, @body.clone, @type_vars.clone, @name_column_number)
    end

    def_equals_and_hash @name, @body, @type_vars
  end

  # While expression.
  #
  #     'while' cond
  #       body
  #     'end'
  #
  class While < ASTNode
    property :cond
    property :body
    property :run_once

    def initialize(@cond, body = nil, @run_once = false)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @cond.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      While.new(@cond.clone, @body.clone, @run_once)
    end

    def_equals_and_hash @cond, @body, @run_once
  end

  # Until expression.
  #
  #     'until' cond
  #       body
  #     'end'
  #
  class Until < ASTNode
    property :cond
    property :body
    property :run_once

    def initialize(@cond, body = nil, @run_once = false)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @cond.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      Until.new(@cond.clone, @body.clone, @run_once)
    end

    def_equals_and_hash @cond, @body, @run_once
  end

  class Generic < ASTNode
    property :name
    property :type_vars

    def initialize(@name, @type_vars : Array)
    end

    def self.new(name, type_var : ASTNode)
      new name, [type_var] of ASTNode
    end

    def accept_children(visitor)
      @name.accept visitor
      @type_vars.each &.accept visitor
    end

    def clone_without_location
      Generic.new(@name.clone, @type_vars.clone)
    end

    def_equals_and_hash @name, @type_vars
  end

  class DeclareVar < ASTNode
    property :var
    property :declared_type

    def initialize(@var, @declared_type)
    end

    def accept_children(visitor)
      var.accept visitor
      declared_type.accept visitor
    end

    def name_length
      var = @var
      case var
      when Var
        var.name.length
      when InstanceVar
        var.name.length
      else
        raise "can't happen"
      end
    end

    def clone_without_location
      DeclareVar.new(@var.clone, @declared_type.clone)
    end

    def_equals_and_hash @var, @declared_type
  end

  class Rescue < ASTNode
    property :body
    property :types
    property :name

    def initialize(body = nil, @types = nil, @name = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
      @types.try &.each &.accept visitor
    end

    def clone_without_location
      Rescue.new(@body.clone, @types.clone, @name)
    end

    def_equals_and_hash @body, @types, @name
  end

  class ExceptionHandler < ASTNode
    property :body
    property :rescues
    property :else
    property :ensure

    def initialize(body = nil, @rescues = nil, @else = nil, @ensure = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
      @rescues.try &.each &.accept visitor
      @else.try &.accept visitor
      @ensure.try &.accept visitor
    end

    def clone_without_location
      ExceptionHandler.new(@body.clone, @rescues.clone, @else.clone, @ensure.clone)
    end

    def_equals_and_hash @body, @rescues, @else, @ensure
  end

  class FunLiteral < ASTNode
    property :def

    def initialize(@def = Def.new("->"))
    end

    def accept_children(visitor)
      @def.accept visitor
    end

    def clone_without_location
      FunLiteral.new(@def.clone)
    end

    def_equals_and_hash @def
  end

  class FunPointer < ASTNode
    property :obj
    property :name
    property :args

    def initialize(@obj, @name, @args = [] of ASTNode)
    end

    def accept_children(visitor)
      @obj.try &.accept visitor
      @args.each &.accept visitor
    end

    def clone_without_location
      FunPointer.new(@obj.clone, @name, @args.clone)
    end

    def_equals_and_hash @obj, @name, @args
  end

  class Union < ASTNode
    property :types

    def initialize(@types)
    end

    def accept_children(visitor)
      @types.each &.accept visitor
    end

    def clone_without_location
      Union.new(@types.clone)
    end

    def_equals_and_hash types
  end

  class Virtual < ASTNode
    property :name

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Virtual.new(@name.clone)
    end

    def_equals_and_hash name
  end

  class Self < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      Self.new
    end

    def hash
      0
    end
  end

  abstract class ControlExpression < ASTNode
    property :exp

    def initialize(@exp = nil : ASTNode?)
    end

    def accept_children(visitor)
      @exp.try &.accept visitor
    end

    def_equals_and_hash exp
  end

  class Return < ControlExpression
    def clone_without_location
      Return.new(@exp.clone)
    end
  end

  class Break < ControlExpression
    def clone_without_location
      Break.new(@exp.clone)
    end
  end

  class Next < ControlExpression
    def clone_without_location
      Next.new(@exp.clone)
    end
  end

  class Yield < ASTNode
    property :exps
    property :scope

    def initialize(@exps = [] of ASTNode, @scope = nil)
    end

    def accept_children(visitor)
      @scope.try &.accept visitor
      @exps.each &.accept visitor
    end

    def clone_without_location
      Yield.new(@exps.clone, @scope.clone)
    end

    def_equals_and_hash @exps, @scope
  end

  class Include < ASTNode
    property :name

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Include.new(@name)
    end

    def_equals_and_hash name
  end

  class Extend < ASTNode
    property :name

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Extend.new(@name)
    end

    def_equals_and_hash name
  end

  class Undef < ASTNode
    property :name

    def initialize(@name)
    end

    def clone_without_location
      Undef.new(@name)
    end

    def_equals_and_hash name
  end

  class LibDef < ASTNode
    property :name
    property :body
    property :name_column_number

    def initialize(@name, body = nil, @name_column_number = 0)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def clone_without_location
      LibDef.new(@name, @body.clone, @name_column_number)
    end

    def_equals_and_hash @name, @libname, @body
  end

  class FunDef < ASTNode
    property :name
    property :args
    property :return_type
    property :varargs
    property :body
    property :real_name
    property :attributes
    property :doc

    def initialize(@name, @args = [] of Arg, @return_type = nil, @varargs = false, @body = nil, @real_name = name)
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @return_type.try &.accept visitor
      @body.try &.accept visitor
    end

    def clone_without_location
      FunDef.new(@name, @args.clone, @return_type.clone, @varargs, @body.clone, @real_name)
    end

    def_equals_and_hash @name, @args, @return_type, @varargs, @body, @real_name
  end

  class TypeDef < ASTNode
    property :name
    property :type_spec
    property :name_column_number

    def initialize(@name, @type_spec, @name_column_number = 0)
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def clone_without_location
      TypeDef.new(@name, @type_spec.clone, @name_column_number)
    end

    def_equals_and_hash @name, @type_spec
  end

  abstract class StructOrUnionDef < ASTNode
    property :name
    property :fields

    def initialize(@name, @fields = [] of Arg)
    end

    def accept_children(visitor)
      @fields.each &.accept visitor
    end

    def_equals_and_hash @name, @fields
  end

  class StructDef < StructOrUnionDef
    property :attributes

    def clone_without_location
      StructDef.new(@name, @fields.clone)
    end
  end

  class UnionDef < StructOrUnionDef
    def clone_without_location
      UnionDef.new(@name, @fields.clone)
    end
  end

  class EnumDef < ASTNode
    property :name
    property :members
    property :base_type
    property :attributes
    property :doc

    def initialize(@name, @members = [] of ASTNode, @base_type = nil)
    end

    def accept_children(visitor)
      @members.each &.accept visitor
      @base_type.try &.accept visitor
    end

    def clone_without_location
      EnumDef.new(@name, @members.clone, @base_type.clone)
    end

    def_equals_and_hash @name, @members, @base_type
  end

  class ExternalVar < ASTNode
    property :name
    property :type_spec
    property :real_name
    property :attributes

    def initialize(@name, @type_spec, @real_name = nil)
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def clone_without_location
      ExternalVar.new(@name, @type_spec.clone, @real_name)
    end

    def_equals_and_hash @name, @type_spec, @real_name
  end

  class External < Def
    property :real_name
    property :varargs
    property! :fun_def

    def initialize(name : String, args : Array(Arg), body, @real_name : String)
      super(name, args, body, nil, nil, nil)
      @varargs = false
    end

    def mangled_name(obj_type)
      real_name
    end

    def compatible_with?(other)
      return false if args.length != other.args.length
      return false if varargs != other.varargs

      args.each_with_index do |arg, i|
        return false if arg.type != other.args[i].type
      end

      type == other.type
    end

    def self.for_fun(name, real_name, args, return_type, varargs, body, fun_def)
      external = External.new(name, args, body, real_name)
      external.varargs = varargs
      external.set_type(return_type)
      external.fun_def = fun_def
      external.location = fun_def.location
      external.attributes = fun_def.attributes
      fun_def.external = external
      external
    end

    def_hash @real_name, @varargs, @fun_def
  end

  class Alias < ASTNode
    property :name
    property :value
    property :doc

    def initialize(@name, @value)
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def clone_without_location
      Alias.new(@name, @value.clone)
    end

    def_equals_and_hash @name, @value
  end

  class Metaclass < ASTNode
    property :name

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Metaclass.new(@name.clone)
    end

    def_equals_and_hash name
  end

  # obj as to
  class Cast < ASTNode
    property :obj
    property :to

    def initialize(@obj, @to)
    end

    def accept_children(visitor)
      @obj.accept visitor
      @to.accept visitor
    end

    def clone_without_location
      Cast.new(@obj.clone, @to.clone)
    end

    def_equals_and_hash @obj, @to
  end

  # typeof(exp, exp, ...)
  class TypeOf < ASTNode
    property :expressions

    def initialize(@expressions)
    end

    def accept_children(visitor)
      @expressions.each &.accept visitor
    end

    def clone_without_location
      TypeOf.new(@expressions.clone)
    end

    def_equals_and_hash expressions
  end

  class Attribute < ASTNode
    property :name
    property :args
    property :named_args
    property :doc

    def initialize(@name, @args = [] of ASTNode, @named_args = nil)
    end

    def accept_children(visitor)
      @args.each &.accept visitor
      @named_args.try &.each &.accept visitor
    end

    def clone_without_location
      Attribute.new(name, @args.clone, @named_args.clone)
    end

    def self.any?(attributes, name)
      attributes.try &.any? { |attr| attr.name == name }
    end

    def_equals_and_hash name, args, named_args
  end

  # A macro expression,
  # surrounded by {{ ... }} (output = true)
  # or by {% ... %} (output = false)
  class MacroExpression < ASTNode
    property exp
    property output

    def initialize(@exp, @output = true)
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def clone_without_location
      MacroExpression.new(@exp.clone, @output)
    end

    def_equals_and_hash exp, output
  end

  # Free text that is part of a macro
  class MacroLiteral < ASTNode
    property value

    def initialize(@value)
    end

    def clone_without_location
      self
    end

    def_equals_and_hash value
  end

  # if inside a macro
  #
  #     {% 'if' cond }
  #       then
  #     [
  #     {% 'else' }
  #       else
  #     ]
  #     %{ 'end' }
  class MacroIf < ASTNode
    property :cond
    property :then
    property :else

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def clone_without_location
      MacroIf.new(@cond.clone, @then.clone, @else.clone)
    end

    def_equals_and_hash @cond, @then, @else
  end

  # for inside a macro:
  #
  #    {- for x1, x2, ... , xn in exp }
  #      body
  #    {- end }
  class MacroFor < ASTNode
    property vars
    property exp
    property body

    def initialize(@vars, @exp, @body)
    end

    def accept_children(visitor)
      @vars.each &.accept visitor
      @exp.accept visitor
      @body.accept visitor
    end

    def clone_without_location
      MacroFor.new(@vars.clone, @exp.clone, @body.clone)
    end

    def_equals_and_hash @vars, @exp, @body
  end

  # An underscore matches against any type
  class Underscore < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      Underscore.new
    end

    def hash
      0
    end
  end

  class Splat < UnaryExpression
    def clone_without_location
      Splat.new(@exp.clone)
    end
  end

  class MagicConstant < ASTNode
    property :name

    def initialize(@name)
    end

    def clone_without_location
      MagicConstant.new(@name)
    end

    def expand_node(location)
      case name
      when :__LINE__
        MagicConstant.expand_line_node(location)
      when :__FILE__
        MagicConstant.expand_file_node(location)
      when :__DIR__
        MagicConstant.expand_dir_node(location)
      else
        raise "Bug: unknown magic constant: #{name}"
      end
    end

    def self.expand_line_node(location)
      NumberLiteral.new(expand_line(location))
    end

    def self.expand_line(location)
      location.try(&.line_number) || 0
    end

    def self.expand_file_node(location)
      StringLiteral.new(expand_file(location))
    end

    def self.expand_file(location)
      location.try(&.filename.to_s) || "?"
    end

    def self.expand_dir_node(location)
      StringLiteral.new(expand_dir(location))
    end

    def self.expand_dir(location)
      location.try(&.dirname) || "?"
    end

    def_equals_and_hash name
  end

  # Ficticious node to represent primitives
  class Primitive < ASTNode
    getter name

    def initialize(@name, @type = nil)
    end

    def clone_without_location
      Primitive.new(@name, @type)
    end

    def_equals_and_hash name
  end

  # Ficticious node to represent a tuple indexer
  class TupleIndexer < Primitive
    getter index

    def initialize(@index)
      @name = :tuple_indexer_known_index
    end

    def clone_without_location
      TupleIndexer.new(index)
    end

    def_equals_and_hash index
  end

  # Ficticious node to represent an id inside a macro
  class MacroId < ASTNode
    property value

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

  # Ficticious node to represent a type inside a macro
  class MacroType < ASTNode
    def initialize(@type)
    end

    def to_macro_id
      @type.to_s
    end

    def clone_without_location
      self
    end

    def_equals_and_hash type
  end
end

require "./to_s"
