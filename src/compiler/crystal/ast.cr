module Crystal
  # Base class for nodes in the grammar.
  abstract class ASTNode
    property location

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

    def to_s_for_macro
      to_s
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
    property :value

    def initialize(@value)
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
    property :value
    property :kind

    def initialize(@value : String, @kind)
    end

    def initialize(value : Number, @kind)
      @value = value.to_s
    end

    def has_sign?
      @value[0] == '+' || @value[0] == '-'
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

    def to_s_for_macro
      @value.to_s
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    property :value

    def initialize(@value)
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      CharLiteral.new(@value)
    end
  end

  class StringLiteral < ASTNode
    property :value

    def initialize(@value)
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      StringLiteral.new(@value)
    end

    def to_s_for_macro
      @value
    end
  end

  class StringInterpolation < ASTNode
    property :expressions

    def initialize(@expressions)
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
    property :value

    def initialize(@value)
    end

    def ==(other : self)
      other.value == value
    end

    def clone_without_location
      SymbolLiteral.new(@value)
    end

    def to_s_for_macro
      @value
    end
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    property :elements
    property :of

    def initialize(@elements = [] of ASTNode, @of = nil)
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
    property :keys
    property :values
    property :of_key
    property :of_value

    def initialize(@keys = [] of ASTNode, @values = [] of ASTNode, @of_key = nil, @of_value = nil)
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
    property :from
    property :to
    property :exclusive

    def initialize(@from, @to, @exclusive)
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

  class RegexLiteral < ASTNode
    property :value
    property :modifiers

    def initialize(@value, @modifiers = 0)
    end

    def ==(other : self)
      other.value == value && other.modifiers == modifiers
    end

    def clone_without_location
      RegexLiteral.new(@value, @modifiers)
    end
  end

  class TupleLiteral < ASTNode
    property :exps

    def initialize(@exps)
    end

    def accept_children(visitor)
      exps.each { |exp| exp.accept visitor }
    end

    def ==(other : self)
      other.exps == exps
    end

    def clone_without_location
      TupleLiteral.new(exps.clone)
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    property :name
    property :out

    def initialize(@name, @type = nil)
      @out = false
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

    def to_s_for_macro
      name
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
    property :args
    property :body

    def initialize(@args = [] of Var, body = nil)
      @body = Expressions.from body
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
    property :obj
    property :name
    property :args
    property :block
    property :block_arg
    property :global
    property :name_column_number
    property :has_parenthesis
    property :name_length

    def initialize(@obj, @name, @args = [] of ASTNode, @block = nil, @block_arg = nil, @global = false, @name_column_number = nil, @has_parenthesis = false)
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

    def to_s_for_macro
      if !obj && !block && args.empty?
        @name
      else
        to_s
      end
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
    property :target
    property :value

    def initialize(@target, @value)
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
    property :targets
    property :values

    def initialize(@targets, @values)
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
    property :name
    property :out

    def initialize(@name, @out = false)
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

    def to_s_for_macro
      @name
    end
  end

  class ClassVar < ASTNode
    property :name
    property :out

    def initialize(@name, @out = false)
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
    property :name

    def initialize(@name)
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
    property :left
    property :right

    def initialize(@left, @right)
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
    property :exp

    def initialize(@exp)
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
    property :name
    property :default_value
    property :restriction

    def initialize(@name, @default_value = nil, @restriction = nil)
    end

    def accept_children(visitor)
      @default_value.accept visitor if @default_value
      @restriction.accept visitor if @restriction
    end

    def ==(other : self)
      other.name == name && other.default_value == default_value && other.restriction == restriction
    end

    def name_length
      name.length
    end

    def clone_without_location
      Arg.new(@name, @default_value.clone, @restriction.clone)
    end
  end

  class Fun < ASTNode
    property :inputs
    property :output

    def initialize(@inputs = nil, @output = nil)
    end

    def accept_children(visitor)
      @inputs.each { |input| input.accept visitor } if @inputs
      @output.accept visitor if @output
    end

    def ==(other : self)
      other.inputs == inputs && other.output == output
    end

    def clone_without_location
      Fun.new(@inputs.clone, @output.clone)
    end
  end

  class BlockArg < ASTNode
    property :name
    property :fun

    def initialize(@name, @fun = Fun.new)
    end

    def accept_children(visitor)
      @fun.accept visitor if @fun
    end

    def ==(other : self)
      other.name == name && other.fun == @fun
    end

    def name_length
      name.length
    end

    def clone_without_location
      BlockArg.new(@name, @fun.clone)
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
    property :receiver
    property :name
    property :args
    property :body
    property :block_arg
    property :yields
    property :instance_vars
    property :calls_super
    property :uses_block_arg
    property :name_column_number

    def initialize(@name, @args : Array(Arg), body = nil, @receiver = nil, @block_arg = nil, @yields = nil)
      @body = Expressions.from body
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
    property :receiver
    property :name
    property :args
    property :body
    property :block_arg
    property :yields
    property :name_column_number

    def initialize(@name, @args : Array(Arg), body = nil, @receiver = nil, @block_arg = nil, @yields = nil)
      @body = Expressions.from body
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
    property :exp

    def initialize(@exp)
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
    property :obj
    property :const

    def initialize(@obj, @const)
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
    property :obj
    property :name

    def initialize(@obj, @name)
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
    property :string

    def initialize(@string)
    end

    def ==(other : self)
      other.string == string
    end

    def clone_without_location
      Require.new(@string)
    end
  end

  class When < ASTNode
    property :conds
    property :body

    def initialize(@conds, body = nil)
      @body = Expressions.from body
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
    property :cond
    property :whens
    property :else

    def initialize(@cond, @whens, @else = nil)
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
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Path < ASTNode
    property :names
    property :global
    property :name_length

    def initialize(@names, @global = false)
    end

    def ==(other : self)
      other.names == names && other.global == global
    end

    def clone_without_location
      ident = Path.new(@names.clone, @global)
      ident.name_length = name_length
      ident
    end

    def to_s_for_macro
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
    property :name
    property :body
    property :superclass
    property :type_vars
    property :abstract
    property :struct
    property :name_column_number

    def initialize(@name, body = nil, @superclass = nil, @type_vars = nil, @abstract = false, @struct = false, @name_column_number = nil)
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @superclass.accept visitor if @superclass
      @body.accept visitor
    end

    def ==(other : self)
      other.name == name && other.body == body && other.superclass == superclass && other.type_vars == type_vars && @abstract == other.abstract && @struct == other.struct
    end

    def clone_without_location
      ClassDef.new(@name, @body.clone, @superclass.clone, @type_vars.clone, @abstract, @struct, @name_column_number)
    end
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

    def initialize(@name, body = nil, @type_vars = nil, @name_column_number = nil)
      @body = Expressions.from body
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

    def ==(other : self)
      other.cond == cond && other.body == body && other.run_once == run_once
    end

    def clone_without_location
      While.new(@cond.clone, @body.clone, @run_once)
    end
  end

  class Generic < ASTNode
    property :name
    property :type_vars

    def initialize(@name, @type_vars)
    end

    def accept_children(visitor)
      @name.accept visitor
      @type_vars.each { |v| v.accept visitor }
    end

    def ==(other : self)
      other.name == name && other.type_vars == type_vars
    end

    def clone_without_location
      Generic.new(@name.clone, @type_vars.clone)
    end
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
    property :body
    property :types
    property :name

    def initialize(body = nil, @types = nil, @name = nil)
      @body = Expressions.from body
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
    property :body
    property :rescues
    property :else
    property :ensure

    def initialize(body = nil, @rescues = nil, @else = nil, @ensure = nil)
      @body = Expressions.from body
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
    property :def

    def initialize(@def = Def.new("->", [] of Arg))
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
    property :obj
    property :name
    property :args

    def initialize(@obj, @name, @args = [] of ASTNode)
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

  class Union < ASTNode
    property :types

    def initialize(@types)
    end

    def ==(other : self)
      other.types == types
    end

    def accept_children(visitor)
      @types.each { |type| type.accept visitor }
    end

    def clone_without_location
      Union.new(@types.clone)
    end
  end

  class Hierarchy < ASTNode
    property :name

    def initialize(@name)
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

  class Self < ASTNode
    def ==(other : self)
      true
    end

    def clone_without_location
      Self.new
    end
  end

  abstract class ControlExpression < ASTNode
    property :exps

    def initialize(@exps = [] of ASTNode)
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
    property :scope

    def initialize(@exps = [] of ASTNode, @scope = nil)
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
    property :name

    def initialize(@name)
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
    property :name
    property :libname
    property :body
    property :name_column_number

    def initialize(@name, @libname = nil, body = nil, @name_column_number = nil)
      @body = Expressions.from body
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
    property :name
    property :args
    property :return_type
    property :varargs
    property :body
    property :real_name

    def initialize(@name, @args = [] of Arg, @return_type = nil, @varargs = false, @body = nil, @real_name = name)
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
    property :name
    property :type_spec
    property :name_column_number

    def initialize(@name, @type_spec, @name_column_number = nil)
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
    property :name
    property :fields

    def initialize(@name, @fields = [] of Arg)
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
    property :name
    property :constants

    def initialize(@name, @constants)
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
    property :name
    property :type_spec
    property :real_name

    def initialize(@name, @type_spec, @real_name = nil)
    end

    def accept_children(visitor)
      @type_spec.accept visitor
    end

    def ==(other : self)
      other.name == name && other.type_spec == type_spec && real_name == other.real_name
    end

    def clone_without_location
      ExternalVar.new(@name, @type_spec.clone, @real_name)
    end
  end

  class External < Def
    property :real_name
    property :varargs
    property! :fun_def
    property :dead

    def initialize(name : String, args : Array(Arg), body, @real_name : String)
      super(name, args, body, nil, nil, nil)
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
      fun_def.external = external
      external
    end
  end

  class Alias < ASTNode
    property :name
    property :value

    def initialize(@name, @value)
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
    property :obj
    property :names

    def initialize(@obj, @names)
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
    property :value

    def initialize(obj, names, @value)
      super(obj, names)
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

  class Metaclass < ASTNode
    property :name

    def initialize(@name)
    end

    def accept_children(visitor)
      @name.accept visitor
    end

    def ==(other : self)
      @name == other.name
    end

    def clone_without_location
      Metaclass.new(@name.clone)
    end
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

    def ==(other : self)
      @obj == other.obj && @to == other.to
    end

    def clone_without_location
      Cast.new(@obj.clone, @to.clone)
    end
  end

  # typeof(exp, exp, ...)
  class TypeOf < ASTNode
    property :expressions

    def initialize(@expressions)
    end

    def accept_children(visitor)
      @expressions.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.expressions == expressions
    end

    def clone_without_location
      TypeOf.new(@expressions.clone)
    end
  end


  # Ficticious node to represent primitives
  class Primitive < ASTNode
    getter name

    def initialize(@name, @type = nil)
    end

    def ==(other : self)
      true
    end

    def clone_without_location
      Primitive.new(@name, @type)
    end
  end

  # Ficticious node to represent a tuple indexer
  class TupleIndexer < Primitive
    getter index

    def initialize(@index)
      @name = :tuple_indexer_known_index
    end

    def ==(other : self)
      index == other.index
    end

    def clone_without_location
      TupleIndexer.new(index)
    end
  end

  # Ficticious node to cast a node with type FunType to return void
  class CastFunToReturnVoid < Primitive
    getter node

    def initialize(@node)
      @name = :cast_fun_to_return_void
    end

    def clone_without_location
      CastFunToReturnVoid.new(@node)
    end
  end
end

require "to_s"
