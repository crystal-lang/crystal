require "location"

module Crystal
  # Base class for nodes in the grammar.
  abstract class ASTNode
    def location
      @location
    end

    def location=(location)
      @location = location.clone
    end

    def clone
      self
    end

    # def clone
    #   new_node = self.class.allocate
    #   new_node.location = location
    #   new_node.clone_from self
    #   new_node
    # end

    # def clone_from(other)
    # end
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    property :expressions

    def self.from(obj : Nil)
      nil
    end

    def self.from(obj : Array)
      case obj.length
      when 0
        nil
      when 1
        obj.first
      else
        new obj
      end
    end

    def self.from(obj : ASTNode)
      obj
    end

    def initialize(expressions = [] of ASTNode)
      @expressions = expressions
    end

    def ==(other : self)
      other.expressions == expressions
    end

    def empty?
      @expressions.empty?
    end

    def last
      @expressions.last
    end

    def accept_children(visitor)
      @expressions.each { |exp| exp.accept visitor }
    end

    # def clone_from(other : self)
    #   @expressions = other.expressions.map { |e| e.clone }
    # end
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def ==(other : self)
      true
    end
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    property :value

    def initialize(value)
      @value = value
    end

    def ==(other : self)
      other.value == value
    end
  end

  # Any number literal.
  # kind stores a symbol indicating which type is it: i32, u16, f32, f64, etc.
  class NumberLiteral < ASTNode
    property :value
    property :kind
    property :has_sign

    def initialize(value, kind)
      @has_sign = value[0] == '+' || value[0] == '-'
      @value = value
      @kind = kind
    end

    def ==(other : self)
      other.value.to_f64 == value.to_f64 && other.kind == kind
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    property :value

    def initialize(value)
      @value = value
    end

    def ==(other : self)
      other.value == value
    end
  end

  class StringLiteral < ASTNode
    property :value

    def initialize(value)
      @value = value
    end

    def ==(other : self)
      other.value == value
    end
  end

  class StringInterpolation < ASTNode
    property :expressions

    def initialize(expressions)
      @expressions = expressions
    end

    def accept_children(visitor)
      @expressions.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.expressions == expressions
    end
  end

  class SymbolLiteral < ASTNode
    property :value

    def initialize(value)
      @value = value
    end

    def ==(other : self)
      other.value == value
    end
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    property :elements
    property :of

    def initialize(elements = [] of ASTNode, of = nil)
      @elements = elements
      @of = of
    end

    def accept_children(visitor)
      elements.each { |exp| exp.accept visitor }
      @of.accept visitor if @of
    end

    def ==(other : self)
      other.elements == elements && other.of == of
    end

    # def clone_from(other : self)
    #   @elements = other.elements.map { |e| e.clone }
    #   @of = other.of.clone
    # end
  end

  class HashLiteral < ASTNode
    property :keys
    property :values
    property :of_key
    property :of_value

    def initialize(keys = [] of ASTNode, values = [] of ASTNode, of_key = nil, of_value = nil)
      @keys = keys
      @values = values
      @of_key = of_key
      @of_value = of_value
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

    # def clone_from(other : self)
    #   @keys = other.keys.map { |e| e.clone }
    #   @values = other.values.map { |e| e.clone }
    #   @of_key = other.of_key.clone
    #   @of_value = other.of_value.clone
    # end
  end

  class RangeLiteral < ASTNode
    property :from
    property :to
    property :exclusive

    def initialize(from, to, exclusive)
      @from = from
      @to = to
      @exclusive = exclusive
    end

    def ==(other : self)
      other.from == from && other.to == to && other.exclusive == exclusive
    end
  end

  class RegexpLiteral < ASTNode
    property :value

    def initialize(value)
      @value = value
    end

    def ==(other : self)
      other.value == value
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

    property :name_column_number
    property :has_parenthesis
    property :name_length

    def initialize(obj, name, args = [] of ASTNode, block = nil, name_column_number = nil, has_parenthesis = false)
      @obj = obj
      @name = name
      @args = args
      @block = block
      @name_column_number = name_column_number
      @has_parenthesis = has_parenthesis
    end

    def ==(other : self)
      other.obj == obj && other.name == name && other.args == args && other.block == block
    end

    # def name_column_number
    #   @name_column_number || column_number
    # end

    # def name_length
    #   @name_length ||= name.to_s.ends_with?('=') || name.to_s.ends_with?('@') ? name.length - 1 : name.length
    # end
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

    def initialize(cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor if @then
      @else.accept visitor if @else
    end

    def ==(other : self)
      other.cond == cond && other.then == self.then && other.else == self.else
    end
  end

  class Unless < ASTNode
    property :cond
    property :then
    property :else

    def initialize(cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      @cond.accept visitor
      @then.accept visitor if @then
      @else.accept visitor if @else
    end

    def ==(other : self)
      other.cond == cond && other.then == self.then && other.else == self.else
    end
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < ASTNode
    property :target
    property :value

    def initialize(target, value)
      @target = target
      @value = value
    end

    def accept_children(visitor)
      @target.accept visitor
      @value.accept visitor
    end

    def ==(other : self)
      other.target == target && other.value == value
    end
  end

  # Assign expression.
  #
  #     target [',' target]+ '=' value [',' value]*
  #
  class MultiAssign < ASTNode
    property :targets
    property :values

    def initialize(targets, values)
      @targets = targets
      @values = values
    end

    def accept_children(visitor)
      @targets.each { |target| target.accept visitor }
      @values.each { |value| value.accept visitor }
    end

    def ==(other : self)
      other.targets == targets && other.values == values
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    property :name
    property :out
    property :type

    def initialize(name : String, type = nil)
      @name = name
      @type = type
      @out = false
    end

    def ==(other : self)
      other.name == name && other.type == type && other.out == out
    end
  end

  # An instance variable.
  class InstanceVar < ASTNode
    property :name
    property :out

    def initialize(name)
      @name = name
      @out = false
    end

    def ==(other : self)
      other.name == name && other.out == out
    end
  end

  # A global variable.
  class Global < ASTNode
    property :name

    def initialize(name)
      @name = name
    end

    def ==(other)
      other.is_a?(Global) && other.name == name
    end
  end

  class BinaryOp < ASTNode
    property :left
    property :right

    def initialize(left, right)
      @left = left
      @right = right
    end

    def accept_children(visitor)
      left.accept visitor
      right.accept visitor
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
  end

  # Expressions or.
  #
  #     expression '||' expression
  #
  class Or < BinaryOp
  end

  # Expressions simple or (no short-circuit).
  #
  #     expression '||' expression
  #
  class SimpleOr < BinaryOp
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
    property :yields
    property :block_arg
    property :instance_vars
    property :name_column_number

    def initialize(name, args : Array(Arg), body = nil, receiver = nil, block_arg = nil, yields = -1)
      @name = name
      @args = args
      @body = Expressions.from body
      @receiver = receiver
      @block_arg = block_arg
      @yields = yields
    end

    def accept_children(visitor)
      @receiver.accept visitor if @receiver
      args.each { |arg| arg.accept visitor }
      @body.accept visitor if @body
      @block_arg.accept visitor if @block_arg
    end

    def ==(other : self)
      other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.yields == yields && other.block_arg == block_arg
    end
  end

  class Macro < ASTNode
    property :receiver
    property :name
    property :args
    property :body
    property :yields
    property :block_arg
    property :name_column_number

    def initialize(name, args : Array(Arg), body = nil, receiver = nil, block_arg = nil, yields = -1)
      @name = name
      @args = args
      @body = Expressions.from body
      @receiver = receiver
      @block_arg = block_arg
      @yields = yields
    end

    def accept_children(visitor)
      @receiver.accept visitor if @receiver
      args.each { |arg| arg.accept visitor }
      @body.accept visitor if @body
      @block_arg.accept visitor if @block_arg
    end

    def ==(other : self)
      other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.yields == yields && other.block_arg == block_arg
    end
  end

  class PointerOf < ASTNode
    property :var

    def initialize(var)
      @var = var
    end

    def accept_children(visitor)
      @var.accept visitor
    end

    def ==(other : self)
      other.var == var
    end
  end

  class IsA < ASTNode
    property :obj
    property :const

    def initialize(obj, const)
      @obj = obj
      @const = const
    end

    def accept_children(visitor)
      @obj.accept visitor
      @const.accept visitor
    end

    def ==(other : self)
      other.obj == obj && other.const == const
    end
  end

  class Require < ASTNode
    property :string

    def initialize(string)
      @string = string
    end

    def ==(other : self)
      other.string == string
    end
  end

  class Case < ASTNode
    property :cond
    property :whens
    property :else

    def initialize(cond, whens, a_else = nil)
      @cond = cond
      @whens = whens
      @else = a_else
    end

    def accept_children(visitor)
      @whens.each { |w| w.accept visitor }
      @else.accept visitor if @else
    end

    def ==(other : self)
      other.cond == cond && other.whens == whens && other.else == @else
    end
  end

  class When < ASTNode
    property :conds
    property :body

    def initialize(conds, body = nil)
      @conds = conds
      @body = Expressions.from body
    end

    def accept_children(visitor)
      @conds.each { |cond| cond.accept visitor }
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.conds == conds && other.body == body
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
    property :name_column_number

    def initialize(name, body = nil, superclass = nil, type_vars = nil, is_abstract = false, name_column_number = nil)
      @name = name
      @body = Expressions.from body
      @superclass = superclass
      @type_vars = type_vars
      @abstract = is_abstract
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.name == name && other.body == body && other.superclass == superclass && other.type_vars == type_vars && @abstract == other.abstract
    end

    # def clone_from(other : self)
    #   @name = other.name.clone
    #   @body = other.body.clone
    #   @superclass = other.superclass
    #   @type_vars = other.type_vars.clone
    #   @abstract = other.abstract
    #   @name_column_number = other.name_column_number
    # end
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

    def initialize(name, body = nil, type_vars = nil, name_column_number = nil)
      @name = name
      @body = Expressions.from body
      @type_vars = type_vars
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.name == name && other.body == body && other.type_vars == type_vars
    end

    # def clone_from(other : self)
    #   @name = other.name.clone
    #   @body = other.body.clone
    #   if other_type_vars = other.type_vars
    #     @type_vars = other_type_vars.map { |e| e.clone }
    #   end
    #   @name_column_number = other.name_column_number
    # end
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

    def initialize(cond, body = nil, run_once = false)
      @cond = cond
      @body = Expressions.from body
      @run_once = run_once
    end

    def accept_children(visitor)
      @cond.accept visitor
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.cond == cond && other.body == body && other.run_once == run_once
    end
  end

  class RangeLiteral < ASTNode
    property :from
    property :to
    property :exclusive

    def initialize(from, to, exclusive)
      @from = from
      @to = to
      @exclusive = exclusive
    end

    def ==(other : self)
      other.from == from && other.to == to && other.exclusive == exclusive
    end
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Ident < ASTNode
    property :names
    property :global

    def initialize(names, global = false)
      @names = names
      @global = global
    end

    def ==(other : self)
      other.names == names && other.global == global
    end
  end

  class NewGenericClass < ASTNode
    property :name
    property :type_vars

    def initialize(name, type_vars)
      @name = name
      @type_vars = type_vars
    end

    def accept_children(visitor)
      @name.accept visitor
      @type_vars.each { |v| v.accept visitor }
    end

    def ==(other : self)
      other.name == name && other.type_vars == type_vars
    end
  end

  class ExceptionHandler < ASTNode
    property :body
    property :rescues
    property :else
    property :ensure

    def initialize(body = nil, rescues = nil, a_else = nil, a_ensure = nil)
      @body = Expressions.from body
      @rescues = rescues
      @else = a_else
      @ensure = a_ensure
    end

    def accept_children(visitor)
      @body.accept visitor if @body
      @rescues.each { |a_rescue| a_rescue.accept visitor } if @rescues
      @else.accept visitor if @else
      @ensure.accept visitor if @ensure
    end

    def ==(other : self)
      other.body == body && other.rescues == rescues && other.else == @else && other.ensure == @ensure
    end
  end

  class Rescue < ASTNode
    property :body
    property :types
    property :name

    def initialize(body = nil, types = nil, name = nil)
      @body = Expressions.from body
      @types = types
      @name = name
    end

    def accept_children(visitor)
      @body.accept visitor if @body
      @types.each { |type| type.accept visitor } if @types
    end

    def ==(other : self)
      body == body && other.types == types && other.name == name
    end
  end

  class IdentUnion < ASTNode
    property :idents

    def initialize(idents)
      @idents = idents
    end

    def ==(other : self)
      other.idents == idents
    end

    def accept_children(visitor)
      @idents.each { |ident| ident.accept visitor }
    end
  end

  # A def argument.
  class Arg < ASTNode
    property :name
    property :default_value
    property :type_restriction
    property :out

    def initialize(name, default_value = nil, type_restriction = nil)
      @name = name.to_s
      @default_value = default_value
      @type_restriction = type_restriction
      @out = false
    end

    def accept_children(visitor)
      @default_value.accept visitor if @default_value
      @type_restriction.accept visitor if @type_restriction
    end

    def ==(other : self)
      other.name == name && other.default_value == default_value && other.type_restriction == type_restriction && other.out == out
    end
  end

  class BlockArg < ASTNode
    property :name
    property :inputs
    property :output

    def initialize(name, inputs = nil, output = nil)
      @name = name
      @inputs = inputs
      @output = output
    end

    def accept_children(visitor)
      @inputs.each { |input| input.accept visitor } if @inputs
      @output.accept visitor if @output
    end

    def ==(other : self)
      other.name == name && other.inputs == inputs && other.output == output
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

    def initialize(args = [] of ASTNode, body = nil)
      @args = args
      @body = Expressions.from body
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.args == args && other.body == body
    end
  end

  class SelfType < ASTNode
    def ==(other : self)
      true
    end
  end

  class ControlExpression < ASTNode
    property :exps

    def initialize(exps = [] of ASTNode)
      @exps = exps
    end

    def accept_children(visitor)
      exps.each { |e| e.accept visitor }
    end

    def ==(other : self)
      other.exps == exps
    end
  end

  class Return < ControlExpression
  end

  class Break < ControlExpression
  end

  class Yield < ControlExpression
  end

  class Next < ControlExpression
  end

  class Include < ASTNode
    property :name

    def initialize(name)
      @name = name
    end

    def accept_children(visitor)
      name.accept visitor
    end

    def ==(other : self)
      other.name == name
    end
  end

  class LibDef < ASTNode
    property :name
    property :libname
    property :body
    property :name_column_number

    def initialize(name, libname = nil, body = nil, name_column_number = nil)
      @name = name
      @libname = libname
      @body = Expressions.from body
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      @body.accept visitor if @body
    end

    def ==(other : self)
      other.name == name && other.libname == libname && other.body == body
    end
  end

  class FunDef < ASTNode
    property :name
    property :args
    property :return_type
    property :pointer
    property :varargs
    property :real_name

    def initialize(name, args = [] of ASTNode, return_type = nil, pointer = 0, varargs = false, real_name = name)
      @name = name
      @real_name = real_name
      @args = args
      @return_type = return_type
      @pointer = pointer
      @varargs = varargs
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      @return_type.accept visitor if @return_type
    end

    def ==(other : self)
      other.name == name && other.args == args && other.return_type == return_type && other.pointer == pointer && other.real_name == real_name && other.varargs == varargs
    end
  end

  class FunDefArg < ASTNode
    property :name
    property :type_spec
    property :pointer

    def initialize(name, type_spec, pointer = 0)
      @name = name
      @type_spec = type_spec
      @pointer = pointer
    end

    def accept_children(visitor)
      type_spec.accept visitor
    end

    def ==(other : self)
      other.name == name && other.type_spec == type_spec && other.pointer == pointer
    end
  end

  class TypeDef < ASTNode
    property :name
    property :type_spec
    property :pointer
    property :name_column_number

    def initialize(name, type_spec, pointer = 0, name_column_number = nil)
      @name = name
      @type_spec = type_spec
      @pointer = pointer
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      type_spec.accept visitor
    end

    def ==(other : self)
      other.name == name && other.type_spec == type_spec && other.pointer == pointer
    end
  end

  class StructOrUnionDef < ASTNode
    property :name
    property :fields

    def initialize(name, fields = [] of FunDefArg)
      @name = name
      @fields = fields
    end

    def accept_children(visitor)
      @fields.each { |field| field.accept visitor }
    end

    def ==(other : self)
      other.name == name && other.fields == fields
    end
  end

  class StructDef < StructOrUnionDef
  end

  class UnionDef < StructOrUnionDef
  end

  class EnumDef < ASTNode
    property :name
    property :constants

    def initialize(name, constants)
      @name = name
      @constants = constants
    end

    def accept_children(visitor)
      @constants.each { |constant| constant.accept visitor }
    end

    def ==(other : self)
      other.name == name && other.constants == constants
    end
  end
end
