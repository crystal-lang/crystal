require_relative 'core_ext/module'
require_relative 'core_ext/string'
require 'singleton'

module Crystal
  class Visitor
    def visit_any(node)
    end
  end

  # Base class for nodes in the grammar.
  class ASTNode
    attr_accessor :line_number
    attr_accessor :column_number
    attr_accessor :filename

    def location
      [@line_number, @column_number, @filename]
    end

    def location=(location)
      @line_number, @column_number, @filename = location
    end

    def self.inherited(klass)
      name = klass.simple_name.underscore

      klass.class_eval <<-EVAL, __FILE__, __LINE__ + 1
        def accept(visitor)
          visitor.visit_any self
          if visitor.visit_#{name} self
            accept_children visitor
          end
          visitor.end_visit_#{name} self
        end

        def transform(transformer)
          transformer.before_transform self
          node = transformer.transform_#{name} self
          transformer.after_transform self
          node
        end
      EVAL

      Visitor.class_eval <<-EVAL, __FILE__, __LINE__ + 1
        def visit_#{name}(node)
          true
        end

        def end_visit_#{name}(node)
        end
      EVAL
    end

    def accept_children(visitor)
    end

    def clone
      new_node = self.class.allocate
      new_node.location = location
      new_node.clone_from self
      new_node
    end

    def clone_from(other)
    end

    def nop?
      false
    end
  end

  class Nop < ASTNode
    def nop?
      true
    end

    def ==(other)
      other.is_a?(Nop)
    end
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    include Enumerable

    attr_accessor :expressions

    def self.from(obj)
      case obj
      when nil
        Nop.new
      when Array
        if obj.length == 0
          Nop.new
        elsif obj.length == 1
          obj[0]
        else
          new obj
        end
      else
        obj
      end
    end

    def self.concat(exp, expressions)
      expressions = expressions.expressions if expressions.is_a?(Expressions)
      expressions = [expressions] unless expressions.is_a?(Array)

      return exp if expressions.empty?

      while expressions.length == 1 && expressions[0].is_a?(Expressions)
        expressions = expressions[0].expressions
      end

      if exp
        if exp.is_a?(Expressions)
          exp.expressions.concat expressions
          exp
        else
          Expressions.new([exp] + expressions)
        end
      else
        Expressions.from(expressions)
      end
    end

    def initialize(expressions = [])
      @expressions = expressions
    end

    def each(&block)
      @expressions.each(&block)
    end

    def [](i)
      @expressions[i]
    end

    def last
      @expressions.last
    end

    def <<(exp)
      @expressions << exp
    end

    def empty?
      @expressions.empty?
    end

    def accept_children(visitor)
      expressions.each { |exp| exp.accept visitor }
    end

    def ==(other)
      other.is_a?(Expressions) && other.expressions == expressions
    end

    def clone_from(other)
      @expressions = other.expressions.map(&:clone)
    end
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    attr_accessor :elements
    attr_accessor :of

    def initialize(elements = [], of = nil)
      @elements = elements
      @of = of
    end

    def accept_children(visitor)
      elements.each { |exp| exp.accept visitor }
      of.accept visitor if of
    end

    def ==(other)
      other.is_a?(ArrayLiteral) && other.elements == elements && other.of == of
    end

    def clone_from(other)
      @elements = other.elements.map(&:clone)
      @of = other.of.clone if other.of
    end
  end

  class HashLiteral < ASTNode
    attr_accessor :keys
    attr_accessor :values
    attr_accessor :of_key
    attr_accessor :of_value

    def initialize(keys = [], values = [], of_key = nil, of_value = nil)
      @keys = keys
      @values = values
      @of_key = of_key
      @of_value = of_value
    end

    def accept_children(visitor)
      keys.each { |key| key.accept visitor }
      values.each { |value| value.accept visitor }
      of_key.accept visitor if of_key
      of_value.accept visitor if of_value
    end

    def ==(other)
      other.is_a?(HashLiteral) && other.keys == keys && other.values == values && other.of_key == of_key && other.of_value == of_value
    end

    def clone_from(other)
      @keys = other.keys.map(&:clone)
      @values = other.values.map(&:clone)
      @of_key = other.of_key.clone if other.of_key
      @of_value = other.of_value.clone if other.of_value
    end
  end

  # Class definition:
  #
  #     'class' name [ '<' superclass ]
  #       body
  #     'end'
  #
  class ClassDef < ASTNode
    attr_accessor :name
    attr_accessor :body
    attr_accessor :superclass
    attr_accessor :type_vars
    attr_accessor :abstract
    attr_accessor :name_column_number

    def initialize(name, body = nil, superclass = nil, type_vars = nil, abstract = false, name_column_number = nil)
      @name = name
      @body = Expressions.from body
      @superclass = superclass
      @type_vars = type_vars
      @abstract = abstract
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      name.accept visitor
      superclass.accept visitor if superclass
      body.accept visitor
    end

    def ==(other)
      other.is_a?(ClassDef) && other.name == name && other.body == body && other.superclass == superclass && other.type_vars == type_vars && abstract == other.abstract
    end

    def clone_from(other)
      @name = other.name.clone
      @body = other.body.clone
      @superclass = other.superclass
      @type_vars = other.type_vars.clone
      @abstract = other.abstract
      @name_column_number = other.name_column_number
    end
  end

  # Module definition:
  #
  #     'module' name
  #       body
  #     'end'
  #
  class ModuleDef < ASTNode
    attr_accessor :name
    attr_accessor :body
    attr_accessor :type_vars
    attr_accessor :name_column_number

    def initialize(name, body = nil, type_vars = nil, name_column_number = nil)
      @name = name
      @body = Expressions.from body
      @type_vars = type_vars
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      @name.accept visitor
      @body.accept visitor
    end

    def ==(other)
      other.is_a?(ModuleDef) && other.name == name && other.body == body && other.type_vars == type_vars
    end

    def clone_from(other)
      @name = other.name.clone
      @body = other.body.clone
      @type_vars = other.type_vars.map(&:clone) if other.type_vars
      @name_column_number = other.name_column_number
    end
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def ==(other)
      other.is_a?(NilLiteral)
    end
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(BoolLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  # Any number literal.
  # kind stores a symbol indicating which type is it: i32, u16, f32, f64, etc.
  class NumberLiteral < ASTNode
    attr_accessor :value
    attr_reader :has_sign
    attr_reader :kind

    def initialize(value, kind)
      @has_sign = value.is_a?(String) && (value[0] == '+' || value[0] == '-')
      @value = value
      @kind = kind
    end

    def integer?
      @kind != :f32 && @kind != :f64
    end

    def ==(other)
      other.is_a?(NumberLiteral) && other.value.to_f == value.to_f && other.kind == kind
    end

    def clone_from(other)
      @value = other.value
      @kind = other.kind
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(CharLiteral) && other.value.to_i == value.to_i
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class StringLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(StringLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class StringInterpolation < ASTNode
    attr_accessor :expressions

    def initialize(expressions)
      @expressions = expressions
    end

    def accept_children(visitor)
      @expressions.each { |e| e.accept visitor }
    end

    def ==(other)
      other.is_a?(StringInterpolation) && other.expressions == expressions
    end

    def clone_from(other)
      @expressions = other.expressions.map(&:clone)
    end
  end

  class SymbolLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(SymbolLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
    end
  end

  class RangeLiteral < ASTNode
    attr_accessor :from
    attr_accessor :to
    attr_accessor :exclusive

    def initialize(from, to, exclusive)
      @from = from
      @to = to
      @exclusive = exclusive
    end

    def ==(other)
      other.is_a?(RangeLiteral) && other.from == from && other.to == to && other.exclusive == exclusive
    end

    def accept_children(visitor)
      from.accept visitor
      to.accept visitor
    end

    def clone_from(other)
      @from = other.from
      @to = other.to
      @exclusive = other.exclusive
    end
  end

  class RegexpLiteral < ASTNode
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(RegexpLiteral) && other.value == value
    end

    def clone_from(other)
      @value = other.value
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
    attr_accessor :receiver
    attr_accessor :name
    attr_accessor :args
    attr_accessor :body
    attr_accessor :yields
    attr_accessor :block_arg
    attr_accessor :instance_vars
    attr_accessor :name_column_number

    def initialize(name, args, body = nil, receiver = nil, block_arg = nil, yields = false)
      @name = name
      @args = args
      @body = Expressions.from body
      @receiver = receiver
      @block_arg = block_arg
      @yields = yields
    end

    def accept_children(visitor)
      receiver.accept visitor if receiver
      args.each { |arg| arg.accept visitor }
      body.accept visitor if body
      block_arg.accept visitor if block_arg
    end

    def ==(other)
      other.is_a?(Def) && other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.yields == yields && other.block_arg == block_arg
    end

    def clone_from(other)
      @name = other.name
      @args = other.args.map(&:clone)
      @body = other.body.clone
      @receiver = other.receiver.clone
      @yields = other.yields
      @block_arg = other.block_arg
      @name_column_number = other.name_column_number
    end
  end

  # A local variable or block argument.
  class Var < ASTNode
    attr_accessor :name
    attr_accessor :out

    def initialize(name, type = nil)
      @name = name.to_s
      @type = type
    end

    def ==(other)
      other.is_a?(Var) && other.name == name && other.type == type && other.out == out
    end

    def eql?(other)
      self == other
    end

    def hash
      name.hash ^ out.hash
    end

    def clone_from(other)
      @name = other.name
      @out = other.out
    end
  end

  # A global variable.
  class Global < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name.to_s
    end

    def ==(other)
      other.is_a?(Global) && other.name == name
    end

    def clone_from(other)
      @name = other.name
    end
  end

  # A def argument.
  class Arg < ASTNode
    attr_accessor :name
    attr_accessor :default_value
    attr_accessor :type_restriction

    def initialize(name, default_value = nil, type_restriction = nil)
      @name = name.to_s
      @default_value = default_value
      @type_restriction = type_restriction
    end

    def accept_children(visitor)
      default_value.accept visitor if default_value
      type_restriction.accept visitor if type_restriction && !type_restriction.is_a?(Type)
    end

    def ==(other)
      other.is_a?(Arg) && other.name == name && other.default_value == default_value && other.type_restriction == type_restriction
    end

    def clone_from(other)
      @name = other.name
      @default_value = other.default_value.clone
      @type_restriction = other.type_restriction.clone
    end
  end

  class BlockArg < ASTNode
    attr_accessor :name
    attr_accessor :inputs
    attr_accessor :output

    def initialize(name, inputs = nil, output = nil)
      @name = name
      @inputs = inputs
      @output = output
    end

    def accept_children(visitor)
      inputs.each { |input| input.accept visitor } if inputs
      output.accept visitor if output
    end

    def ==(other)
      other.is_a?(BlockArg) && other.name == name && other.inputs == inputs && other.output == output
    end

    def clone_from(other)
      @name = other.name
      @inputs = other.inputs.map(&:clone) if other.inputs
      @output = other.output.clone
    end
  end

  # A qualified identifier.
  #
  #     const [ '::' const ]*
  #
  class Ident < ASTNode
    attr_accessor :names
    attr_accessor :global
    attr_accessor :name_length

    def initialize(names, global = false)
      @names = names
      @global = global
    end

    def ==(other)
      other.is_a?(Ident) && other.names == names && other.global == global
    end

    def clone_from(other)
      @names = other.names
      @global = other.global
      @name_length = other.name_length
    end
  end

  class IdentUnion < ASTNode
    attr_accessor :idents

    def initialize(idents)
      @idents = idents
    end

    def ==(other)
      other.is_a?(IdentUnion) && other.idents == idents
    end

    def accept_children(visitor)
      @idents.each { |ident| ident.accept visitor }
    end

    def clone_from(other)
      @idents = other.idents.map(&:clone)
    end
  end

  class SelfType < ASTNode
    include Singleton

    def clone
      self
    end
  end

  class InstanceVar < ASTNode
    attr_accessor :name
    attr_accessor :out

    def initialize(name)
      @name = name
    end

    def ==(other)
      other.is_a?(InstanceVar) && other.name == name && other.out == out
    end

    def clone_from(other)
      @name = other.name
      @out = other.out
    end
  end

  class ClassVar < ASTNode
    attr_accessor :name
    attr_accessor :out

    def initialize(name)
      @name = name
    end

    def ==(other)
      other.is_a?(ClassVar) && other.name == name && other.out == out
    end

    def clone_from(other)
      @name = other.name
      @out = other.out
    end
  end

  class BinaryOp < ASTNode
    attr_accessor :left
    attr_accessor :right

    def initialize(left, right)
      @left = left
      @right = right
    end

    def accept_children(visitor)
      left.accept visitor
      right.accept visitor
    end

    def ==(other)
      self.class == other.class && other.left == left && other.right == right
    end

    def clone_from(other)
      @left = other.left.clone
      @right = other.right.clone
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

  # Used only for require "foo" if ...
  class Not < ASTNode
    attr_accessor :exp

    def initialize(exp)
      @exp = exp
    end

    def accept_children(visitor)
      @exp.accept self
    end

    def ==(other)
      other.is_a?(Not) && @exp == other.exp
    end

    def clone_from(other)
      @exp = other.exp.clone
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
    attr_accessor :obj
    attr_accessor :name
    attr_accessor :args
    attr_accessor :block
    attr_accessor :global

    attr_accessor :name_column_number
    attr_accessor :has_parenthesis
    attr_accessor :name_length

    def initialize(obj, name, args = [], block = nil, global = false, name_column_number = nil, has_parenthesis = false)
      @obj = obj
      @name = name
      @args = args || []
      @block = block
      @global = global
      @name_column_number = name_column_number
      @has_parenthesis = has_parenthesis
    end

    def accept_children(visitor)
      obj.accept visitor if obj
      args.each { |arg| arg.accept visitor }
      block.accept visitor if block
    end

    def ==(other)
      other.is_a?(Call) && other.obj == obj && other.name == name && other.args == args && other.block == block && other.global == global
    end

    def clone_from(other)
      @obj = other.obj.clone
      @name = other.name
      @args = other.args.map(&:clone)
      @block = other.block.clone
      @global = other.global
      @name_column_number = other.name_column_number
      @name_length = other.name_length
      @has_parenthesis = other.has_parenthesis
    end

    def name_column_number
      @name_column_number || column_number
    end

    def name_length
      @name_length ||= name.to_s.end_with?('=') || name.to_s.end_with?('@') ? name.length - 1 : name.length
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
    attr_accessor :cond
    attr_accessor :then
    attr_accessor :else
    attr_accessor :binary

    def initialize(cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      self.cond.accept visitor
      self.then.accept visitor if self.then
      self.else.accept visitor if self.else
    end

    def ==(other)
      other.is_a?(If) && other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone_from(other)
      @cond = other.cond.clone
      @then = other.then.clone
      @else = other.else.clone
      @binary = other.binary
    end
  end

  # An unless expression.
  #
  #     'unless' cond
  #       then
  #     [
  #     'else'
  #       else
  #     ]
  #     'end'
  #
  # An if elsif end is parsed as an If whose
  # else is another If.
  class Unless < ASTNode
    attr_accessor :cond
    attr_accessor :then
    attr_accessor :else

    def initialize(cond, a_then = nil, a_else = nil)
      @cond = cond
      @then = Expressions.from a_then
      @else = Expressions.from a_else
    end

    def accept_children(visitor)
      self.cond.accept visitor
      self.then.accept visitor if self.then
      self.else.accept visitor if self.else
    end

    def ==(other)
      other.is_a?(Unless) && other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone_from(other)
      @cond = other.cond.clone
      @then = other.then.clone
      @else = other.else.clone
    end
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < ASTNode
    attr_accessor :target
    attr_accessor :value

    def initialize(target, value)
      @target = target
      @value = value
    end

    def accept_children(visitor)
      target.accept visitor
      value.accept visitor
    end

    def ==(other)
      other.is_a?(Assign) && other.target == target && other.value == value
    end

    def eql?(other)
      self == other
    end

    def hash
      target.hash ^ value.hash
    end

    def clone_from(other)
      @target = other.target.clone
      @value = other.value.clone
    end
  end

  # Assign expression.
  #
  #     target [',' target]+ '=' value [',' value]*
  #
  class MultiAssign < ASTNode
    attr_accessor :targets
    attr_accessor :values

    def initialize(targets, values)
      @targets = targets
      @values = values
    end

    def accept_children(visitor)
      @targets.each { |target| target.accept visitor }
      @values.each { |value| value.accept visitor }
    end

    def ==(other)
      other.is_a?(MultiAssign) && other.targets == targets && other.values == values
    end

    def clone_from(other)
      @targets = other.targets.map(&:clone)
      @values = other.values.map(&:clone)
    end
  end

  # While expression.
  #
  #     'while' cond
  #       body
  #     'end'
  #
  class While < ASTNode
    attr_accessor :cond
    attr_accessor :body
    attr_accessor :run_once

    def initialize(cond, body = nil, run_once = false)
      @cond = cond
      @body = Expressions.from body
      @run_once = run_once
    end

    def accept_children(visitor)
      cond.accept visitor
      body.accept visitor
    end

    def ==(other)
      other.is_a?(While) && other.cond == cond && other.body == body && other.run_once == run_once
    end

    def clone_from(other)
      @cond = other.cond.clone
      @body = other.body.clone
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
    attr_accessor :args
    attr_accessor :body

    def initialize(args = [], body = nil)
      @args = args
      @body = Expressions.from body
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      body.accept visitor
    end

    def ==(other)
      other.is_a?(Block) && other.args == args && other.body == body
    end

    def clone_from(other)
      @args = other.args.map(&:clone)
      @body = other.body.clone
    end
  end

  ['return', 'break', 'next'].each do |keyword|
    # A #{keyword} expression.
    #
    #     '#{keyword}' [ '(' ')' ]
    #   |
    #     '#{keyword}' '(' arg [ ',' arg ]* ')'
    #   |
    #     '#{keyword}' arg [ ',' arg ]*
    #
    class_eval <<-EVAL, __FILE__, __LINE__ + 1
      class #{keyword.capitalize} < ASTNode
        attr_accessor :exps

        def initialize(exps = [])
          @exps = exps
        end

        def accept_children(visitor)
          exps.each { |e| e.accept visitor }
        end

        def ==(other)
          other.is_a?(#{keyword.capitalize}) && other.exps == exps
        end

        def clone_from(other)
          @exps = other.exps.map(&:clone)
        end
      end
    EVAL
  end

  class Yield < ASTNode
    attr_accessor :exps
    attr_accessor :scope

    def initialize(exps = [], scope = nil)
      @exps = exps
      @scope = scope
    end

    def accept_children(visitor)
      scope.accept visitor if scope
      exps.each { |e| e.accept visitor }
    end

    def ==(other)
      other.is_a?(Yield) && other.scope == scope && other.exps == exps
    end

    def clone_from(other)
      @scope = other.scope.clone
      @exps = other.exps.map(&:clone)
    end
  end

  class LibDef < ASTNode
    attr_accessor :name
    attr_accessor :libname
    attr_accessor :body
    attr_accessor :name_column_number

    def initialize(name, libname = nil, body = nil, name_column_number = nil)
      @name = name
      @libname = libname
      @body = Expressions.from body
      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      body.accept visitor
    end

    def ==(other)
      other.is_a?(LibDef) && other.name == name && other.libname == libname && other.body == body
    end
  end

  class FunDef < ASTNode
    attr_accessor :name
    attr_accessor :args
    attr_accessor :return_type
    attr_accessor :ptr
    attr_accessor :varargs
    attr_accessor :body
    attr_accessor :real_name

    def initialize(name, args = [], return_type = nil, ptr = 0, varargs = false, body = nil, real_name = name)
      @name = name
      @real_name = real_name
      @args = args
      @return_type = return_type
      @ptr = ptr
      @varargs = varargs
      @body = body
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      return_type.accept visitor if return_type
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(FunDef) && other.name == name && other.args == args && other.return_type == return_type && other.ptr == ptr && other.real_name == real_name && other.varargs == varargs && other.body == body
    end
  end

  class FunDefArg < ASTNode
    attr_accessor :name
    attr_accessor :type
    attr_accessor :ptr

    def initialize(name, type, ptr = 0)
      @name = name
      @type = type
      @ptr = ptr
    end

    def accept_children(visitor)
      type.accept visitor
    end

    def ==(other)
      other.is_a?(FunDefArg) && other.name == name && other.type == type && other.ptr == ptr
    end
  end

  class TypeDef < ASTNode
    attr_accessor :name
    attr_accessor :type
    attr_accessor :ptr
    attr_accessor :name_column_number

    def initialize(name, type, ptr = 0, name_column_number = nil)
      @name = name
      @type = type
      @ptr = ptr

      @name_column_number = name_column_number
    end

    def accept_children(visitor)
      type.accept visitor
    end

    def ==(other)
      other.is_a?(TypeDef) && other.name == name && other.type == type && other.ptr == ptr
    end
  end

  class StructOrUnionDef < ASTNode
    attr_accessor :name
    attr_accessor :fields

    def initialize(name, fields = [])
      @name = name
      @fields = fields
    end

    def accept_children(visitor)
      fields.each { |field| field.accept visitor }
    end

    def ==(other)
      other.is_a?(self.class) && other.name == name && other.fields == fields
    end
  end

  class StructDef < StructOrUnionDef
  end

  class UnionDef < StructOrUnionDef
  end

  class EnumDef < ASTNode
    attr_accessor :name
    attr_accessor :constants

    def initialize(name, constants)
      @name = name
      @constants = constants
    end

    def accept_children(visitor)
      constants.each { |constant| constant.accept visitor }
    end

    def ==(other)
      other.is_a?(EnumDef) && other.name == name && other.constants == constants
    end
  end

  class Include < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def accept_children(visitor)
      name.accept visitor
    end

    def ==(other)
      other.is_a?(Include) && other.name == name
    end

    def clone_from(other)
      @name = other.name
    end
  end

  class Macro < ASTNode
    attr_accessor :receiver
    attr_accessor :name
    attr_accessor :args
    attr_accessor :body
    attr_accessor :block_arg
    attr_accessor :name_column_number

    def initialize(name, args, body = nil, receiver = nil, block_arg = nil, yields = nil)
      @name = name
      @args = args
      @body = Expressions.from body
      @receiver = receiver
      @block_arg = block_arg
    end

    def accept_children(visitor)
      receiver.accept visitor if receiver
      args.each { |arg| arg.accept visitor }
      body.accept visitor
      block_arg.accept visitor if block_arg
    end

    def ==(other)
      other.is_a?(Macro) && other.receiver == receiver && other.name == name && other.args == args && other.body == body && other.block_arg == block_arg
    end

    def clone_from(other)
      @name = other.name
      @args = other.args.map(&:clone)
      @body = other.body.clone
      @receiver = other.receiver.clone
      @block_arg = other.block_arg
      @name_column_number = other.name_column_number
    end

    def yields
      false
    end
  end

  class PointerOf < ASTNode
    attr_accessor :var

    def initialize(var)
      @var = var
    end

    def accept_children(visitor)
      var.accept visitor
    end

    def ==(other)
      other.is_a?(PointerOf) && other.var == var
    end

    def clone_from(other)
      @var = other.var.clone
    end
  end

  class IsA < ASTNode
    attr_accessor :obj
    attr_accessor :const

    def initialize(obj, const)
      @obj = obj
      @const = const
    end

    def accept_children(visitor)
      obj.accept visitor
      const.accept visitor
    end

    def ==(other)
      other.is_a?(IsA) && other.obj == obj && other.const == const
    end

    def clone_from(other)
      @obj = other.obj.clone
      @const = other.const.clone
    end
  end

  class RespondsTo < ASTNode
    attr_accessor :obj
    attr_accessor :name

    def initialize(obj, name)
      @obj = obj
      @name = name
    end

    def accept_children(visitor)
      obj.accept visitor
      name.accept visitor
    end

    def ==(other)
      other.is_a?(RespondsTo) && other.obj == obj && other.name == name
    end

    def clone_from(other)
      @obj = other.obj.clone
      @name = other.name.clone
    end
  end

  class Require < ASTNode
    attr_accessor :string
    attr_accessor :cond

    def initialize(string, cond = nil)
      @string = string
      @cond = cond
    end

    def accept_children(visitor)
      @cond.accept visitor if @cond
    end

    def ==(other)
      other.is_a?(Require) && other.string == string && other.cond == cond
    end

    def clone_from(other)
      @string = other.string.clone
      @cond = other.cond.clone
    end
  end

  class Case < ASTNode
    attr_accessor :cond
    attr_accessor :whens
    attr_accessor :else

    def initialize(cond, whens, a_else = nil)
      @cond = cond
      @whens = whens
      @else = a_else
    end

    def accept_children(visitor)
      @whens.each { |w| w.accept visitor }
      @else.accept visitor if @else
    end

    def ==(other)
      other.is_a?(Case) && other.cond == cond && other.whens == whens && other.else == @else
    end

    def clone_from(other)
      @cond = other.cond.clone
      @whens = other.whens.map(&:clone)
      @else = other.else.clone
    end
  end

  class When < ASTNode
    attr_accessor :conds
    attr_accessor :body

    def initialize(conds, body = nil)
      @conds = conds
      @body = Expressions.from body
    end

    def accept_children(visitor)
      conds.each { |cond| cond.accept visitor }
      body.accept visitor
    end

    def ==(other)
      other.is_a?(When) && other.conds == conds && other.body == body
    end

    def clone_from(other)
      @conds = other.conds.map(&:clone)
      @body = other.body.clone
    end
  end

  class NewGenericClass < ASTNode
    attr_accessor :name
    attr_accessor :type_vars

    def initialize(name, type_vars)
      @name = name
      @type_vars = type_vars
    end

    def accept_children(visitor)
      name.accept visitor
      type_vars.each { |v| v.accept visitor }
    end

    def ==(other)
      other.is_a?(NewGenericClass) && other.name == name && other.type_vars == type_vars
    end

    def clone_from(other)
      @name = other.name
      @type_vars = other.type_vars.map(&:clone)
    end
  end

  class DeclareVar < ASTNode
    attr_accessor :name
    attr_accessor :declared_type

    def initialize(name, declared_type)
      @name = name
      @declared_type = declared_type
    end

    def accept_children(visitor)
      declared_type.accept visitor
    end

    def ==(other)
      other.is_a?(DeclareVar) && other.name == name && other.declared_type == declared_type
    end

    def clone_from(other)
      @name = other.name
      @declared_type = other.declared_type
    end
  end

  class ExceptionHandler < ASTNode
    attr_accessor :body
    attr_accessor :rescues
    attr_accessor :else
    attr_accessor :ensure

    def initialize(body = nil, rescues = nil, a_else = nil, a_ensure = nil)
      @body = Expressions.from body
      @rescues = rescues
      @else = a_else
      @ensure = a_ensure
    end

    def accept_children(visitor)
      @body.accept visitor
      @rescues.each { |a_rescue| a_rescue.accept visitor } if @rescues
      @else.accept visitor if @else
      @ensure.accept visitor if @ensure
    end

    def handles_all?
      @rescues && !@rescues.last.types
    end

    def ==(other)
      other.is_a?(ExceptionHandler) && other.body == body && other.rescues == rescues && other.else == @else && other.ensure == @ensure
    end

    def clone_from(other)
      @body = other.body.clone
      @rescues = other.rescues.map(&:clone) if other.rescues
      @else = other.else.clone
      @ensure = other.ensure.clone
    end
  end

  class Rescue < ASTNode
    attr_accessor :body
    attr_accessor :types
    attr_accessor :name

    def initialize(body = nil, types = nil, name = nil)
      @body = Expressions.from body
      @types = types
      @name = name
    end

    def accept_children(visitor)
      @body.accept visitor
      @types.each { |type| type.accept visitor } if @types
    end

    def ==(other)
      other.is_a?(Rescue) && other.body == body && other.types == types && other.name == name
    end

    def clone_from(other)
      @body = other.body.clone
      @types = other.types.map(&:clone) if other.types
      @name = other.name
    end
  end

  # Ficticious node that means: merge the type of the arguments
  class TypeMerge < ASTNode
    attr_accessor :expressions

    def initialize(expressions)
      @expressions = expressions
    end

    def accept_children(visitor)
      @expressions.each { |e| e.accept visitor }
    end

    def ==(other)
      other.is_a?(TypeMerge) && other.expressions == expressions
    end

    def clone_from(other)
      @expressions = other.expressions.map(&:clone)
    end
  end
end
