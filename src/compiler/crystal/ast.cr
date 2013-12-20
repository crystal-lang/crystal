require "location"

# Some forward declarations
class Array(T); end
class Hash(K, V); end
class Set(T); end

module Crystal
  # Need forward declaration to define instance variables' types
  abstract class Type; end
  abstract class TypeFilter; end
  abstract class ASTNode; end
  class Call < ASTNode; end

  # Base class for nodes in the grammar.
  class ASTNode
    @type :: Type+?
    @location :: Location?
    @dependencies :: Array(ASTNode)?
    @type_filters :: Hash(String, TypeFilter)?
    @freeze_type :: Bool?
    @observers :: Array(ASTNode)?
    @input_observers :: Array(Call)?
    @dirty :: Bool?

    def type?
      @type
    end

    def clone
      clone = clone_without_location
      clone.location = location
      clone
    end

    def name_column_number
      @location ? @location.column_number : nil
    end

    def name_length
      nil
    end

    def nop?
      false
    end

    def class_name
      raise "class_name not yet implemented for #{self.to_s_node}"
    end

    def to_s
      to_s_node
    end
  end

  class Nop < ASTNode
    def nop?
      true
    end

    def ==(other : self)
      true
    end

    def clone_without_location
      Nop.new
    end
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    @expressions :: Array(ASTNode)

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

    def expressions=(@expressions)
    end

    def expressions
      @expressions
    end

    def ==(other : self)
      other.expressions == expressions
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
      @expressions.each { |exp| exp.accept visitor }
    end

    def clone_without_location
      Expressions.new(@expressions.clone)
    end
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      self
    end
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    @value :: Bool

    def initialize(@value)
    end

    def value=(@value)
    end

    def value
      @value
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      BoolLiteral.new(@value)
    end
  end

  # Any number literal.
  # kind stores a symbol indicating which type is it: i32, u16, f32, f64, etc.
  class NumberLiteral < ASTNode
    @value :: String
    @kind :: Symbol
    @has_sign :: Bool

    def initialize(@value : String, @kind)
      @has_sign = value[0] == '+' || value[0] == '-'
    end

    def initialize(value : Number, @kind)
      @value = value.to_s
      @has_sign = false
    end

    def value=(@value)
    end

    def value
      @value
    end

    def kind=(@kind)
    end

    def kind
      @kind
    end

    def has_sign
      @has_sign
    end

    def ==(other : self)
      other.value.to_f64 == value.to_f64 && other.kind == kind
    end

    def hash
      31 * value.hash + kind.hash
    end

    def clone_without_location
      NumberLiteral.new(@value, @kind)
    end

    def to_s
      @value.to_s
    end

    def class_name
      "NumberLiteral"
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    @value :: String

    def initialize(@value)
    end

    def value=(@value)
    end

    def value
      @value
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      CharLiteral.new(@value)
    end
  end

  class StringLiteral < ASTNode
    @value :: String

    def initialize(@value)
    end

    def value=(@value)
    end

    def value
      @value
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      StringLiteral.new(@value)
    end

    def class_name
      "StringLiteral"
    end

    def to_s
      @value
    end
  end

  class StringInterpolation < ASTNode
    @expressions :: Array(ASTNode)

    def initialize(@expressions)
    end

    def expressions=(@expressions)
    end

    def expressions
      @expressions
    end

    def accept_children(visitor)
      @expressions.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.expressions == expressions
    end

    def clone_without_location
      StringInterpolation.new(@expressions.clone)
    end
  end

  class SymbolLiteral < ASTNode
    @value :: String

    def initialize(@value)
    end

    def value=(@value)
    end

    def value
      @value
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      SymbolLiteral.new(@value)
    end

    def to_s
      @value
    end

    def class_name
      "SymbolLiteral"
    end
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    @elements :: Array(ASTNode)
    @of :: ASTNode+?

    def initialize(@elements = [] of ASTNode, @of = nil)
    end

    def elements=(@elements)
    end

    def elements
      @elements
    end

    def of=(@of)
    end

    def of
      @of
    end

    def accept_children(visitor)
      elements.each { |exp| exp.accept visitor }
      @of.accept visitor if @of
    end

    def ==(other : self)
      other.elements == elements && other.of == of
    end

    def clone_without_location
      ArrayLiteral.new(@elements.clone, @of.clone)
    end
  end

  class HashLiteral < ASTNode
    @keys :: Array(ASTNode)
    @values :: Array(ASTNode)
    @of_key :: ASTNode+?
    @of_value :: ASTNode+?

    def initialize(@keys = [] of ASTNode, @values = [] of ASTNode, @of_key = nil, @of_value = nil)
    end

    def keys=(@keys)
    end

    def keys
      @keys
    end

    def values=(@values)
    end

    def values
      @values
    end

    def of_key=(@of_key)
    end

    def of_key
      @of_key
    end

    def of_value=(@of_value)
    end

    def of_value
      @of_value
    end

    def accept_children(visitor)
      @keys.each { |key| key.accept visitor }
      @values.each { |value| value.accept visitor }
      @of_key.accept visitor if @of_key
      @of_value.accept visitor if @of_value
    end

    def ==(other : self)
      other.keys == keys && other.values == values && other.of_key == of_key && other.of_value == of_value
    end

    def clone_without_location
      HashLiteral.new(@keys.clone, @values.clone, @of_key.clone, @of_value.clone)
    end
  end

  class RangeLiteral < ASTNode
    @from :: ASTNode+
    @to :: ASTNode+
    @exclusive :: Bool

    def initialize(@from, @to, @exclusive)
    end

    def from=(@from)
    end

    def from
      @from
    end

    def to=(@to)
    end

    def to
      @to
    end

    def exclusive=(@exclusive)
    end

    def exclusive
      @exclusive
    end

    def accept_children(visitor)
      @from.accept visitor
      @to.accept visitor
    end

    def ==(other : self)
      other.from == from && other.to == to && other.exclusive == exclusive
    end

    def clone_without_location
      RangeLiteral.new(@from.clone, @to.clone, @exclusive.clone)
    end
  end

  class RegexpLiteral < ASTNode
    @value :: String

    def initialize(value)
      @value = value
    end

    def value=(@value)
    end

    def value
      @value
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      RegexpLiteral.new(@value)
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    @name :: String
    @out :: Bool

    def initialize(@name, @type = nil)
      @out = false
    end

    def name=(@name)
    end

    def name
      @name
    end

    def out=(@out)
    end

    def out
      @out
    end

    def name_length
      name.length
    end

    def ==(other : self)
      other.name == name && other.type? == type? && other.out == out
    end

    def clone_without_location
      var = Var.new(@name)
      var.out = @out
      var
    end

    def to_s
      name
    end

    def class_name
      "Var"
    end
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
    @args :: Array(Var)
    @body :: ASTNode+

    def initialize(@args = [] of Var, body = nil)
      @body = Expressions.from body
    end

    def args=(@args)
    end

    def args
      @args
    end

    def body=(@body)
    end

    def body
      @body
    end

    def accept_children(visitor)
      @args.each { |arg| arg.accept visitor }
      @body.accept visitor
    end

    def ==(other : self)
      other.args == args && other.body == body
    end

    def clone_without_location
      Block.new(@args.clone, @body.clone)
    end
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
    @obj :: ASTNode+?
    @name :: String
    @args :: Array(ASTNode)
    @block :: Block?
    @block_arg :: ASTNode+?
    @global :: Bool
    @name_column_number :: Int32?
    @has_parenthesis :: Bool
    @name_length :: Int32?

    def initialize(@obj, @name, @args = [] of ASTNode, @block = nil, @block_arg = nil, @global = false, @name_column_number = nil, @has_parenthesis = false)
    end

    def obj=(@obj)
    end

    def obj
      @obj
    end

    def name=(@name)
    end

    def name
      @name
    end

    def args=(@args)
    end

    def args
      @args
    end

    def block=(@block)
    end

    def block
      @block
    end

    def block_arg=(@block_arg)
    end

    def block_arg
      @block_arg
    end

    def global=(@global)
    end

    def global
      @global
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def has_parenthesis=(@has_parenthesis)
    end

    def has_parenthesis
      @has_parenthesis
    end

    def name_length=(@name_length)
    end

    def name_length
      @name_length ||= name.to_s.ends_with?('=') || name.to_s.ends_with?('@') ? name.length - 1 : name.length
    end

    def accept_children(visitor)
      @obj.accept visitor if @obj
      @args.each { |arg| arg.accept visitor }
      @block_arg.accept visitor if @block_arg
      @block.accept visitor if @block
    end

    def ==(other : self)
      other.obj == obj && other.name == name && other.args == args && other.block_arg == block_arg && other.block == block && other.global == global
    end

    def clone_without_location
      clone = Call.new(@obj.clone, @name, @args.clone, @block.clone, @block_arg.clone, @global, @name_column_number, @has_parenthesis)
      clone.name_length = name_length
      clone
    end

    def to_s
      if !obj && !block && args.empty?
        @name
      else
        to_s_node
      end
    end

    def class_name
      "Call"
    end
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
    @cond :: ASTNode+
    @then :: ASTNode+
    @else :: ASTNode+
    @binary :: Symbol?

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def cond=(@cond)
    end

    def cond
      @cond
    end

    def then=(@then)
    end

    def then
      @then
    end

    def else=(@else)
    end

    def else
      @else
    end

    def binary=(@binary)
    end

    def binary
      @binary
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def ==(other : self)
      other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone_without_location
      a_if = If.new(@cond.clone, @then.clone, @else.clone)
      a_if.binary = binary
      a_if
    end
  end

  class Unless < ASTNode
    @cond :: ASTNode+
    @then :: ASTNode+
    @else :: ASTNode+

    def initialize(@cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def cond=(@cond)
    end

    def cond
      @cond
    end

    def then=(@then)
    end

    def then
      @then
    end

    def else=(@else)
    end

    def else
      @else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def ==(other : self)
      other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone_without_location
      Unless.new(@cond.clone, @then.clone, @else.clone)
    end
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
    @cond :: ASTNode+
    @then :: ASTNode+
    @else :: ASTNode+

    def initialize(@cond, a_then = nil, a_else = nil)
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def cond=(@cond)
    end

    def cond
      @cond
    end

    def then=(@then)
    end

    def then
      @then
    end

    def else=(@else)
    end

    def else
      @else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor
      @else.accept visitor
    end

    def ==(other : self)
      other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone_without_location
      IfDef.new(@cond.clone, @then.clone, @else.clone)
    end
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < ASTNode
    @target :: ASTNode+
    @value :: ASTNode+

    def initialize(@target, @value)
    end

    def target=(@target)
    end

    def target
      @target
    end

    def value=(@value)
    end

    def value
      @value
    end

    def accept_children(visitor)
      @target.accept visitor
      @value.accept visitor
    end

    def ==(other : self)
      other.target == target && other.value == value
    end

    def clone_without_location
      Assign.new(@target.clone, @value.clone)
    end
  end

  # Assign expression.
  #
  #     target [',' target]+ '=' value [',' value]*
  #
  class MultiAssign < ASTNode
    @targets :: Array(ASTNode)
    @values :: Array(ASTNode)

    def initialize(@targets, @values)
    end

    def targets=(@targets)
    end

    def targets
      @targets
    end

    def values=(@values)
    end

    def values
      @values
    end

    def accept_children(visitor)
      @targets.each { |target| target.accept visitor }
      @values.each { |value| value.accept visitor }
    end

    def ==(other : self)
      other.targets == targets && other.values == values
    end

    def clone_without_location
      MultiAssign.new(@targets.clone, @values.clone)
    end
  end

  # An instance variable.
  class InstanceVar < ASTNode
    @name :: String
    @out :: Bool

    def initialize(@name, @out = false)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def out=(@out)
    end

    def out
      @out
    end

    def name_length
      name.length
    end

    def ==(other : self)
      other.name == name && other.out == out
    end

    def clone_without_location
      InstanceVar.new(@name, @out)
    end

    def to_s
      @name
    end

    def class_name
      "InstanceVar"
    end
  end

  class ClassVar < ASTNode
    @name :: String
    @out :: Bool

    def initialize(@name, @out = false)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def out=(@out)
    end

    def out
      @out
    end

    def ==(other : self)
      other.name == @name && other.out == @out
    end

    def clone_without_location
      ClassVar.new(@name, @out)
    end
  end

  # A global variable.
  class Global < ASTNode
    @name :: String

    def initialize(@name)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def name_length
      name.length
    end

    def ==(other)
      other.is_a?(Global) && other.name == name
    end

    def clone_without_location
      Global.new(@name)
    end
  end

  abstract class BinaryOp < ASTNode
    @left :: ASTNode+
    @right :: ASTNode+

    def initialize(@left, @right)
    end

    def left=(@left)
    end

    def left
      @left
    end

    def right=(@right)
    end

    def right
      @right
    end

    def accept_children(visitor)
      @left.accept visitor
      @right.accept visitor
    end

    def ==(other : self)
      other.left == left && other.right == right
    end
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

  # Expressions simple or (no short-circuit).
  #
  #     expression '||' expression
  #
  class SimpleOr < BinaryOp
    def clone_without_location
      SimpleOr.new(@left.clone, @right.clone)
    end
  end

  # Used only for flags
  class Not < ASTNode
    @exp :: ASTNode+

    def initialize(@exp)
    end

    def exp=(@exp)
    end

    def exp
      @exp
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def ==(other : self)
      @exp == other.exp
    end

    def clone_without_location
      Not.new(@exp.clone)
    end
  end

  # A def argument.
  class Arg < ASTNode
    @name :: String
    @default_value :: ASTNode+?
    @type_restriction :: ASTNode+?

    def initialize(@name, @default_value = nil, @type_restriction = nil)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def default_value=(@default_value)
    end

    def default_value
      @default_value
    end

    def type_restriction=(@type_restriction)
    end

    def type_restriction
      @type_restriction
    end

    def accept_children(visitor)
      @default_value.accept visitor if @default_value
      @type_restriction.accept visitor if @type_restriction
    end

    def ==(other : self)
      other.name == name && other.default_value == default_value && other.type_restriction == type_restriction# && other.out == out
    end

    def name_length
      name.length
    end

    def clone_without_location
      Arg.new(@name, @default_value.clone, @type_restriction.clone)
    end
  end

  class FunTypeSpec < ASTNode
    @inputs :: Array(ASTNode)?
    @output :: ASTNode+?

    def initialize(@inputs = nil, @output = nil)
    end

    def inputs=(@inputs)
    end

    def inputs
      @inputs
    end

    def output=(@output)
    end

    def output
      @output
    end

    def accept_children(visitor)
      @inputs.each { |input| input.accept visitor } if @inputs
      @output.accept visitor if @output
    end

    def ==(other : self)
      other.inputs == inputs && other.output == output
    end

    def clone_without_location
      FunTypeSpec.new(@inputs.clone, @output.clone)
    end
  end

  class BlockArg < ASTNode
    @name :: String
    @type_spec :: FunTypeSpec

    def initialize(@name, @type_spec = FunTypeSpec.new)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def type_spec=(@type_spec)
    end

    def type_spec
      @type_spec
    end

    def accept_children(visitor)
      @type_spec.accept visitor if @type_spec
    end

    def ==(other : self)
      other.name == name && other.type_spec == type_spec
    end

    def name_length
      name.length
    end

    def clone_without_location
      BlockArg.new(@name, @type_spec.clone)
    end
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
    @receiver :: ASTNode+?
    @name :: String
    @args :: Array(Arg)
    @body :: ASTNode+
    @block_arg :: BlockArg?
    @yields :: Int32?
    @instance_vars :: Set(String)?
    @calls_super :: Bool?
    @uses_block_arg :: Bool?
    @name_column_number :: Int32?

    def initialize(@name, @args : Array(Arg), body = nil, @receiver = nil, @block_arg = nil, @yields = nil)
      @body = Expressions.from body
    end

    def receiver=(@receiver)
    end

    def receiver
      @receiver
    end

    def name=(@name)
    end

    def name
      @name
    end

    def args=(@args)
    end

    def args
      @args
    end

    def body=(@body)
    end

    def body
      @body
    end

    def block_arg=(@block_arg)
    end

    def block_arg
      @block_arg
    end

    def yields=(@yields)
    end

    def yields
      @yields
    end

    def instance_vars=(@instance_vars)
    end

    def instance_vars
      @instance_vars
    end

    def calls_super=(@calls_super)
    end

    def calls_super
      @calls_super
    end

    def uses_block_arg=(@uses_block_arg)
    end

    def uses_block_arg
      @uses_block_arg
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def accept_children(visitor)
      @receiver.accept visitor if @receiver
      @args.each { |arg| arg.accept visitor }
      @body.accept visitor
      @block_arg.accept visitor if @block_arg
    end

    def ==(other : self)
      other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.yields == yields && other.block_arg == block_arg
    end

    def name_length
      name.length
    end

    def clone_without_location
      a_def = Def.new(@name, @args.clone, @body.clone, @receiver.clone, @block_arg.clone, @yields)
      a_def.instance_vars = instance_vars
      a_def.calls_super = calls_super
      a_def.uses_block_arg = uses_block_arg
      a_def.name_column_number = name_column_number
      a_def
    end
  end

  class Macro < ASTNode
    @receiver :: ASTNode+?
    @name :: String
    @args :: Array(Arg)
    @body :: ASTNode+
    @block_arg :: BlockArg?
    @yields :: Int32?
    @name_column_number :: Int32?

    def initialize(@name, @args : Array(Arg), body = nil, @receiver = nil, @block_arg = nil, @yields = nil)
      @body = Expressions.from body
    end

    def receiver=(@receiver)
    end

    def receiver
      @receiver
    end

    def name=(@name)
    end

    def name
      @name
    end

    def args=(@args)
    end

    def args
      @args
    end

    def body=(@body)
    end

    def body
      @body
    end

    def block_arg=(@block_arg)
    end

    def block_arg
      @block_arg
    end

    def yields=(@yields)
    end

    def yields
      @yields
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def accept_children(visitor)
      @receiver.accept visitor if @receiver
      @args.each { |arg| arg.accept visitor }
      @body.accept visitor
      @block_arg.accept visitor if @block_arg
    end

    def ==(other : self)
      other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.yields == yields && other.block_arg == block_arg
    end

    def name_length
      name.length
    end

    def clone_without_location
      Macro.new(@name, @args.clone, @body.clone, @receiver.clone, @block_arg.clone, @yields)
    end
  end

  class PointerOf < ASTNode
    @exp :: ASTNode+

    def initialize(@exp)
    end

    def exp=(@exp)
    end

    def exp
      @exp
    end

    def accept_children(visitor)
      @exp.accept visitor
    end

    def ==(other : self)
      other.exp == exp
    end

    def clone_without_location
      PointerOf.new(@exp.clone)
    end
  end

  class IsA < ASTNode
    @obj :: ASTNode+
    @const :: ASTNode+

    def initialize(@obj, @const)
    end

    def obj=(@obj)
    end

    def obj
      @obj
    end

    def const=(@const)
    end

    def const
      @const
    end

    def accept_children(visitor)
      @obj.accept visitor
      @const.accept visitor
    end

    def ==(other : self)
      other.obj == obj && other.const == const
    end

    def clone_without_location
      IsA.new(@obj.clone, @const.clone)
    end
  end

  class RespondsTo < ASTNode
    @obj :: ASTNode+
    @name :: SymbolLiteral

    def initialize(@obj, @name)
    end

    def obj=(@obj)
    end

    def obj
      @obj
    end

    def name=(@name)
    end

    def name
      @name
    end

    def accept_children(visitor)
      obj.accept visitor
      name.accept visitor
    end

    def ==(other : self)
      other.obj == obj && other.name == name
    end

    def clone_without_location
      RespondsTo.new(@obj.clone, @name)
    end
  end

  class Require < ASTNode
    @string :: String

    def initialize(@string)
    end

    def string=(@string)
    end

    def string
      @string
    end

    def ==(other : self)
      other.string == string
    end

    def clone_without_location
      Require.new(@string)
    end
  end

  class When < ASTNode
    @conds :: Array(ASTNode)
    @body :: ASTNode+

    def initialize(@conds, body = nil)
      @body = Expressions.from body
    end

    def conds=(@conds)
    end

    def conds
      @conds
    end

    def body=(@body)
    end

    def body
      @body
    end

    def accept_children(visitor)
      @conds.each { |cond| cond.accept visitor }
      @body.accept visitor
    end

    def ==(other : self)
      other.conds == conds && other.body == body
    end

    def clone_without_location
      When.new(@conds.clone, @body.clone)
    end
  end

  class Case < ASTNode
    @cond :: ASTNode+
    @whens :: Array(When)
    @else :: ASTNode+?

    def initialize(@cond, @whens, @else = nil)
    end

    def cond=(@cond)
    end

    def cond
      @cond
    end

    def whens=(@whens)
    end

    def whens
      @whens
    end

    def else=(@else)
    end

    def else
      @else
    end

    def accept_children(visitor)
      @whens.each { |w| w.accept visitor }
      @else.accept visitor if @else
    end

    def ==(other : self)
      other.cond == cond && other.whens == whens && other.else == @else
    end

    def clone_without_location
      Case.new(@cond.clone, @whens.clone, @else.clone)
    end
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Ident < ASTNode
    @names :: Array(String)
    @global :: Bool
    @name_length :: Int32?

    def initialize(@names, @global = false)
    end

    def names=(@names)
    end

    def names
      @names
    end

    def global=(@global)
    end

    def global
      @global
    end

    def name_length=(@name_length)
    end

    def name_length
      @name_length
    end

    def ==(other : self)
      other.names == names && other.global == global
    end

    def clone_without_location
      ident = Ident.new(@names.clone, @global)
      ident.name_length = name_length
      ident
    end

    def class_name
      "Ident"
    end

    def to_s
      @names.join "::"
    end
  end

  # Class definition:
  #
  #     'class' name [ '<' superclass ]
  #       body
  #     'end'
  #
  class ClassDef < ASTNode
    @name :: Ident
    @body :: ASTNode+
    @superclass :: ASTNode+?
    @type_vars :: Array(String)?
    @abstract :: Bool
    @name_column_number :: Int32?

    def initialize(@name, body = nil, @superclass = nil, @type_vars = nil, @abstract = false, @name_column_number = nil)
      @body = Expressions.from body
    end

    def name=(@name)
    end

    def name
      @name
    end

    def body=(@body)
    end

    def body
      @body
    end

    def superclass=(@superclass)
    end

    def superclass
      @superclass
    end

    def type_vars=(@type_vars)
    end

    def type_vars
      @type_vars
    end

    def abstract=(@abstract)
    end

    def abstract
      @abstract
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def accept_children(visitor)
      @superclass.accept visitor if @superclass
      @body.accept visitor
    end

    def ==(other : self)
      other.name == name && other.body == body && other.superclass == superclass && other.type_vars == type_vars && @abstract == other.abstract
    end

    def clone_without_location
      ClassDef.new(@name, @body.clone, @superclass.clone, @type_vars.clone, @abstract, @name_column_number)
    end
  end

  # Module definition:
  #
  #     'module' name
  #       body
  #     'end'
  #
  class ModuleDef < ASTNode
    @name :: Ident
    @body :: ASTNode+
    @type_vars :: Array(String)?
    @name_column_number :: Int32?

    def initialize(@name, body = nil, @type_vars = nil, @name_column_number = nil)
      @body = Expressions.from body
    end

    def name=(@name)
    end

    def name
      @name
    end

    def body=(@body)
    end

    def body
      @body
    end

    def type_vars=(@type_vars)
    end

    def type_vars
      @type_vars
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def ==(other : self)
      other.name == name && other.body == body && other.type_vars == type_vars
    end

    def clone_without_location
      ModuleDef.new(@name, @body.clone, @type_vars.clone, @name_column_number)
    end
  end

  # While expression.
  #
  #     'while' cond
  #       body
  #     'end'
  #
  class While < ASTNode
    @cond :: ASTNode+
    @body :: ASTNode+
    @run_once :: Bool

    def initialize(@cond, body = nil, @run_once = false)
      @body = Expressions.from body
    end

    def cond=(@cond)
    end

    def cond
      @cond
    end

    def body=(@body)
    end

    def body
      @body
    end

    def run_once=(@run_once)
    end

    def run_once
      @run_once
    end

    def accept_children(visitor)
      @cond.accept visitor
      @body.accept visitor
    end

    def ==(other : self)
      other.cond == cond && other.body == body && other.run_once == run_once
    end

    def clone_without_location
      While.new(@cond.clone, @body.clone, @run_once)
    end
  end

  class NewGenericClass < ASTNode
    @name :: Ident
    @type_vars :: Array(ASTNode)

    def initialize(@name, @type_vars)
    end

    def accept_children(visitor)
      @name.accept visitor
      @type_vars.each { |v| v.accept visitor }
    end

    def name=(@name)
    end

    def name
      @name
    end

    def type_vars=(@type_vars)
    end

    def type_vars
      @type_vars
    end

    def ==(other : self)
      other.name == name && other.type_vars == type_vars
    end

    def clone_without_location
      NewGenericClass.new(@name.clone, @type_vars.clone)
    end
  end

  class DeclareVar < ASTNode
    @var :: ASTNode+
    @declared_type :: ASTNode+

    def initialize(@var, @declared_type)
    end

    def var=(@var)
    end

    def var
      @var
    end

    def declared_type=(@declared_type)
    end

    def declared_type
      @declared_type
    end

    def accept_children(visitor)
      var.accept visitor
      declared_type.accept visitor
    end

    def ==(other : self)
      other.var == var && other.declared_type == declared_type
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
  end

  class Rescue < ASTNode
    @body :: ASTNode+
    @types :: Array(ASTNode)?
    @name :: String?

    def initialize(body = nil, @types = nil, @name = nil)
      @body = Expressions.from body
    end

    def body=(@body)
    end

    def body
      @body
    end

    def types=(@types)
    end

    def types
      @types
    end

    def name=(@name)
    end

    def name
      @name
    end

    def accept_children(visitor)
      @body.accept visitor
      @types.each { |type| type.accept visitor } if @types
    end

    def ==(other : self)
      body == body && other.types == types && other.name == name
    end

    def clone_without_location
      Rescue.new(@body.clone, @types.clone, @name)
    end
  end

  class ExceptionHandler < ASTNode
    @body :: ASTNode+
    @rescues :: Array(Rescue)?
    @else :: ASTNode+?
    @ensure :: ASTNode+?

    def initialize(body = nil, @rescues = nil, @else = nil, @ensure = nil)
      @body = Expressions.from body
    end

    def body=(@body)
    end

    def body
      @body
    end

    def rescues=(@rescues)
    end

    def rescues
      @rescues
    end

    def else=(@else)
    end

    def else
      @else
    end

    def ensure=(@ensure)
    end

    def ensure
      @ensure
    end

    def accept_children(visitor)
      @body.accept visitor
      @rescues.each { |a_rescue| a_rescue.accept visitor } if @rescues
      @else.accept visitor if @else
      @ensure.accept visitor if @ensure
    end

    def ==(other : self)
      other.body == body && other.rescues == rescues && other.else == @else && other.ensure == @ensure
    end

    def clone_without_location
      ExceptionHandler.new(@body.clone, @rescues.clone, @else.clone, @ensure.clone)
    end
  end

  class FunLiteral < ASTNode
    @def :: Def

    def initialize(@def = Def.new("->", [] of Arg))
    end

    def def=(@def)
    end

    def def
      @def
    end

    def accept_children(visitor)
      @def.accept visitor
    end

    def ==(other : self)
      other.def == @def
    end

    def clone_without_location
      FunLiteral.new(@def.clone)
    end
  end

  class FunPointer < ASTNode
    @obj :: ASTNode+?
    @name :: String
    @args :: Array(ASTNode)

    def initialize(@obj, @name, @args = [] of ASTNode)
    end

    def obj=(@obj)
    end

    def obj
      @obj
    end

    def name=(@name)
    end

    def name
      @name
    end

    def args=(@args)
    end

    def args
      @args
    end

    def accept_children(visitor)
      @obj.accept visitor if @obj
      @args.each &.accept visitor
    end

    def ==(other : self)
      other.obj == obj && other.name == name && other.args == args
    end

    def clone_without_location
      FunPointer.new(@obj.clone, @name, @args.clone)
    end
  end

  class IdentUnion < ASTNode
    @idents :: Array(ASTNode)

    def initialize(@idents)
    end

    def idents=(@idents)
    end

    def idents
      @idents
    end

    def ==(other : self)
      other.idents == idents
    end

    def accept_children(visitor)
      @idents.each { |ident| ident.accept visitor }
    end

    def clone_without_location
      IdentUnion.new(@idents.clone)
    end
  end

  class Hierarchy < ASTNode
    @name :: ASTNode+

    def initialize(@name)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def ==(other : self)
      other.name == name
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      Hierarchy.new(@name.clone)
    end
  end

  class StaticArray < ASTNode
    @name :: ASTNode+
    @size :: Int32

    def initialize(@name, @size)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def size=(@size)
    end

    def size
      @size
    end

    def ==(other : self)
      other.name == name && other.size == size
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def clone_without_location
      StaticArray.new(@name.clone, @size)
    end
  end

  class SelfType < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      SelfType.new
    end
  end

  abstract class ControlExpression < ASTNode
    @exps :: Array(ASTNode)

    def initialize(@exps = [] of ASTNode)
    end

    def exps=(@exps)
    end

    def exps
      @exps
    end

    def accept_children(visitor)
      @exps.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.exps == exps
    end
  end

  class Return < ControlExpression
    def clone_without_location
      Return.new(@exps.clone)
    end
  end

  class Break < ControlExpression
    def clone_without_location
      Break.new(@exps.clone)
    end
  end

  class Yield < ControlExpression
    @scope :: ASTNode+?

    def initialize(@exps = [] of ASTNode, @scope = nil)
    end

    def scope=(@scope)
    end

    def scope
      @scope
    end

    def accept_children(visitor)
      @scope.accept visitor if @scope
      @exps.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.scope == scope && other.exps == exps
    end

    def clone_without_location
      Yield.new(@exps.clone, @scope.clone)
    end
  end

  class Next < ControlExpression
    def clone_without_location
      Next.new(@exps.clone)
    end
  end

  class Include < ASTNode
    @name :: ASTNode+

    def initialize(@name)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def ==(other : self)
      other.name == name
    end

    def clone_without_location
      Include.new(@name)
    end
  end

  class LibDef < ASTNode
    @name :: String
    @libname :: String?
    @body :: ASTNode+
    @name_column_number :: Int32?

    def initialize(@name, @libname = nil, body = nil, @name_column_number = nil)
      @body = Expressions.from body
    end

    def name=(@name)
    end

    def name
      @name
    end

    def libname=(@libname)
    end

    def libname
      @libname
    end

    def body=(@body)
    end

    def body
      @body
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def accept_children(visitor)
      @body.accept visitor
    end

    def ==(other : self)
      other.name == name && other.libname == libname && other.body == body
    end

    def clone_without_location
      LibDef.new(@name, @libname, @body.clone, @name_column_number)
    end
  end

  class FunDef < ASTNode
    @name :: String
    @args :: Array(Arg)
    @return_type :: ASTNode+?
    @varargs :: Bool
    @body :: ASTNode+?
    @real_name :: String

    def initialize(@name, @args = [] of Arg, @return_type = nil, @varargs = false, @body = nil, @real_name = name)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def args=(@args)
    end

    def args
      @args
    end

    def return_type=(@return_type)
    end

    def return_type
      @return_type
    end

    def varargs=(@varargs)
    end

    def varargs
      @varargs
    end

    def body=(@body)
    end

    def body
      @body
    end

    def real_name=(@real_name)
    end

    def real_name
      @real_name
    end

    def accept_children(visitor)
      @args.each { |arg| arg.accept visitor }
      @return_type.accept visitor if @return_type
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.name == name && other.args == args && other.return_type == return_type && other.real_name == real_name && other.varargs == varargs && other.body == body
    end

    def clone_without_location
      FunDef.new(@name, @args.clone, @return_type.clone, @varargs, @body.clone, @real_name)
    end
  end

  class TypeDef < ASTNode
    @name :: String
    @type_spec :: ASTNode+
    @name_column_number :: Int32?

    def initialize(@name, @type_spec, @name_column_number = nil)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def type_spec=(@type_spec)
    end

    def type_spec
      @type_spec
    end

    def name_column_number=(@name_column_number)
    end

    def name_column_number
      @name_column_number
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def ==(other : self)
      other.name == name && other.type_spec == type_spec
    end

    def clone_without_location
      TypeDef.new(@name, @type_spec.clone, @name_column_number)
    end
  end

  abstract class StructOrUnionDef < ASTNode
    @name :: String
    @fields :: Array(Arg)

    def initialize(@name, @fields = [] of Arg)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def fields=(@fields)
    end

    def fields
      @fields
    end

    def accept_children(visitor)
      @fields.each { |field| field.accept visitor }
    end

    def ==(other : self)
      other.name == name && other.fields == fields
    end
  end

  class StructDef < StructOrUnionDef
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
    @name :: String
    @constants :: Array(Arg)

    def initialize(@name, @constants)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def constants=(@constants)
    end

    def constants
      @constants
    end

    def accept_children(visitor)
      @constants.each { |constant| constant.accept visitor }
    end

    def ==(other : self)
      other.name == name && other.constants == constants
    end

    def clone_without_location
      EnumDef.new(@name, @constants.clone)
    end
  end

  class ExternalVar < ASTNode
    @name :: String
    @type_spec :: ASTNode+

    def initialize(@name, @type_spec)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def type_spec=(@type_spec)
    end

    def type_spec
      @type_spec
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def ==(other : self)
      other.name == name && other.type_spec == type_spec
    end

    def clone_without_location
      ExternalVar.new(@name, @type_spec.clone)
    end
  end

  class External < Def
    @real_name :: String
    @varargs :: Bool?
    @fun_def :: Def?
    @dead :: Bool?

    def initialize(name : String, args : Array(Arg), body = nil, receiver = nil, block_arg = nil, yields = -1, @real_name : String)
      super(name, args, body, receiver, block_arg, yields)
    end

    def real_name=(@real_name)
    end

    def real_name
      @real_name
    end

    def varargs=(@varargs)
    end

    def varargs
      @varargs
    end

    def fun_def=(@fun_def)
    end

    def fun_def?
      @fun_def
    end

    def fun_def
      @fun_def.not_nil!
    end

    def mangled_name(obj_type)
      real_name
    end

    def dead=(@dead)
    end

    def dead
      @dead
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
      external = External.new(name, args, body, nil, nil, nil, real_name)
      external.varargs = varargs
      external.set_type(return_type)
      external.fun_def = fun_def
      fun_def.external = external
      external
    end
  end

  class Alias < ASTNode
    @name :: String
    @value :: ASTNode+

    def initialize(@name, @value)
    end

    def name=(@name)
    end

    def name
      @name
    end

    def value=(@value)
    end

    def value
      @value
    end

    def accept_children(visitor)
      @value.accept visitor
    end

    def ==(other : self)
      @name == other.name && @value == other.value
    end

    def clone_without_location
      Alias.new(@name, @value.clone)
    end
  end

  class IndirectRead < ASTNode
    @obj :: ASTNode+
    @names :: Array(String)

    def initialize(@obj, @names)
    end

    def obj=(@obj)
    end

    def obj
      @obj
    end

    def names=(@names)
    end

    def names
      @names
    end

    def accept_children(visitor)
      @obj.accept visitor
    end

    def ==(other : self)
      @obj == other.obj && @names == other.names
    end

    def clone_without_location
      IndirectRead.new(@obj.clone, @names)
    end
  end

  class IndirectWrite < IndirectRead
    @value :: ASTNode+

    def initialize(obj, names, @value)
      super(obj, names)
    end

    def value=(@value)
    end

    def value
      @value
    end

    def accept_children(visitor)
      @obj.accept visitor
      @value.accept visitor
    end

    def ==(other : self)
      @obj == other.obj && @names == other.names && @value == other.value
    end

    def clone_without_location
      IndirectWrite.new(@obj.clone, @names, @value.clone)
    end
  end

  # Ficticious node to represent primitives
  class Primitive < ASTNode
    @name :: Symbol

    def initialize(@name, @type = nil)
    end

    # def name=(@name)
    # end

    def name
      @name
    end

    def ==(other : self)
      true
    end

    def clone_without_location
      Primitive.new(@name, @type)
    end
  end

  # Ficticious node to cast a node with type FunType to return void
  class CastFunToReturnVoid < Primitive
    @node :: ASTNode+

    def initialize(@node)
      @name = :cast_fun_to_return_void
    end

    def node
      @node
    end

    def clone_without_location
      CastFunToReturnVoid.new(@node)
    end
  end

  # Ficticious node that means: merge the type of the arguments
  class TypeMerge < ASTNode
    @expressions :: Array(ASTNode)

    def initialize(@expressions)
    end

    def expressions=(@expressions)
    end

    def expressions
      @expressions
    end

    def accept_children(visitor)
      @expressions.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.expressions == expressions
    end

    def clone_without_location
      TypeMerge.new(@expressions.clone)
    end
  end

  # Ficticious node used in the codegen phase to say
  # "this is a node that has his type casted"
  class CastedVar < ASTNode
    @name :: String

    def initialize(@name)
    end

    def name
      @name
    end

    def clone_without_location
      CastedVar.new(@name)
    end
  end
end

require "to_s"
