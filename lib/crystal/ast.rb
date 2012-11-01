require_relative 'core_ext/module'
require_relative 'core_ext/string'

module Crystal
  class Visitor
    def visit_any(node)
    end
  end

  # Base class for nodes in the grammar.
  class ASTNode
    attr_accessor :line_number
    attr_accessor :column_number
    attr_accessor :parent

    def location
      [@line_number, @column_number]
    end

    def location=(line_and_column_number)
      @line_number, @column_number = line_and_column_number
    end

    def self.inherited(klass)
      name = klass.simple_name.underscore

      klass.class_eval %Q(
        def accept(visitor)
          visitor.visit_any self
          if visitor.visit_#{name} self
            accept_children visitor
          end
          visitor.end_visit_#{name} self
        end
      )

      Visitor.class_eval %Q(
        def visit_#{name}(node)
          true
        end

        def end_visit_#{name}(node)
        end
      )
    end

    def accept_children(visitor)
    end

    def clone(&block)
      new_node = self.class.new
      block.call(self, new_node) if block
      new_node
    end
  end

  # A container for one or many expressions.
  # A method's body and a block's body, for
  # example, are Expressions.
  class Expressions < ASTNode
    include Enumerable

    attr_accessor :expressions

    def self.from(obj)
      case obj
      when nil
        nil
      when ::Array
        if obj.length == 0
          nil
        elsif obj.length == 1
          obj[0]
        else
          new obj
        end
      else
        obj
      end
    end

    def initialize(expressions = [])
      @expressions = expressions
      @expressions.each { |e| e.parent = self }
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
      exp.parent = self
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

    def clone(&block)
      exps = Expressions.new expressions.map { |exp| exp.clone(&block) }
      exps.location = location
      block.call(self, exps) if block
      exps
    end
  end

  # An array literal.
  #
  #  '[' ( expression ( ',' expression )* ) ']'
  #
  class ArrayLiteral < ASTNode
    attr_accessor :elements

    def initialize(elements = [])
      @elements = elements
      @elements.each { |e| e.parent = self }
    end


    def accept_children(visitor)
      elements.each { |exp| exp.accept visitor }
    end

    def ==(other)
      other.is_a?(ArrayLiteral) && other.elements == elements
    end

    def clone(&block)
      exps = ArrayLiteral.new elements.map { |exp| exp.clone(&block) }
      exps.location = location
      block.call(self, exps) if block
      exps
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
    attr_accessor :name_column_number
    attr_accessor :superclass_column_number

    def initialize(name, body = nil, superclass = nil, name_column_number = nil, superclass_column_number = nil)
      @name = name
      @body = Expressions.from body
      @body.parent = self if @body
      @superclass = superclass
      @name_column_number = name_column_number
      @superclass_column_number = superclass_column_number
    end

    def accept_children(visitor)
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(ClassDef) && other.name == name && other.body == body && other.superclass == superclass
    end

    def clone(&block)
      class_def = ClassDef.new name, (body ? body.clone(&block) : nil), superclass
      class_def.location = location
      class_def.name_column_number = name_column_number
      class_def.superclass_column_number = superclass_column_number
      block.call(self, class_def) if block
      class_def
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

    def clone(&block)
      other = NilLiteral.new
      block.call(self, other) if block
      other
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

    def clone(&block)
      other = BoolLiteral.new value
      block.call(self, other) if block
      other
    end
  end

  # An integer literal.
  #
  #     \d+
  #
  class IntLiteral < ASTNode
    attr_accessor :value
    attr_reader :has_sign

    def initialize(value)
      @has_sign = value.is_a?(String) && (value[0] == '+' || value[0] == '-')
      @value = value.to_i
    end

    def ==(other)
      other.is_a?(IntLiteral) && other.value.to_i == value.to_i
    end

    def clone(&block)
      other = IntLiteral.new value
      block.call(self, other) if block
      other
    end
  end

  # A long literal.
  #
  #     \d+L
  #
  class LongLiteral < ASTNode
    attr_accessor :value
    attr_reader :has_sign

    def initialize(value)
      @has_sign = value.is_a?(String) && (value[0] == '+' || value[0] == '-')
      @value = value.to_i
    end

    def ==(other)
      other.is_a?(LongLiteral) && other.value.to_i == value.to_i
    end

    def clone(&block)
      other = LongLiteral.new value
      block.call(self, other) if block
      other
    end
  end

  # A float literal.
  #
  #     \d+.\d+
  #
  class FloatLiteral < ASTNode
    attr_accessor :value
    attr_reader :has_sign

    def initialize(value)
      @has_sign = value.is_a?(String) && (value[0] == '+' || value[0] == '-')
      @value = value.to_f
    end

    def ==(other)
      other.is_a?(FloatLiteral) && other.value.to_f == value.to_f
    end

    def clone(&block)
      other = FloatLiteral.new value
      block.call(self, other) if block
      other
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

    def clone(&block)
      other = CharLiteral.new value
      block.call(self, other) if block
      other
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

    def clone(&block)
      other = StringLiteral.new value
      block.call(self, other) if block
      other
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

    def initialize(name, args, body = nil, receiver = nil)
      @name = name
      @args = args
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self if @body
      @receiver = receiver
      @receiver.parent = self if @receiver
    end

    def accept_children(visitor)
      reciever.accept visitor if receiver
      args.each { |arg| arg.accept visitor }
      body.accept visitor if body
    end

    def ==(other)
      other.is_a?(Def) && other.receiver == receiver && other.name == name && other.args == args && other.body == body
    end

    def clone(&block)
      a_def = Def.new name, args.map { |arg| arg.clone(&block) }, (body ? body.clone(&block) : nil), receiver ? receiver.clone(&block) : nil
      a_def.location = location
      block.call(self, a_def) if block
      a_def
    end
  end

  # A local variable or def or block argument.
  class Var < ASTNode
    attr_accessor :name

    def initialize(name, type = nil)
      @name = name
      @type = type
    end

    def ==(other)
      other.is_a?(Var) && other.name == name && other.type == type
    end

    def clone(&block)
      var = Var.new name
      var.location = location
      block.call(self, var) if block
      var
    end
  end

  # A Class name or constant name.
  class Const < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def ==(other)
      other.is_a?(Const) && other.name == name
    end

    def clone(&block)
      var = Const.new name
      var.location = location
      block.call(self, var) if block
      var
    end
  end

  # An instance variable.
  class InstanceVar < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def ==(other)
      other.is_a?(InstanceVar) && other.name == name
    end

    def clone(&block)
      var = InstanceVar.new name
      var.location = location
      block.call(self, var) if block
      var
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

    attr_accessor :name_column_number
    attr_accessor :has_parenthesis
    attr_accessor :name_length

    def initialize(obj, name, args = [], block = nil, name_column_number = nil, has_parenthesis = false)
      @obj = obj
      @obj.parent = self if @obj
      @name = name
      @args = args || []
      @args.each { |arg| arg.parent = self }
      @block = block
      @block.parent = self if @block
      @name_column_number = name_column_number
      @has_parenthesis = has_parenthesis
    end

    def accept_children(visitor)
      obj.accept visitor if obj
      args.each { |arg| arg.accept visitor }
      block.accept visitor if block
    end

    def ==(other)
      other.is_a?(Call) && other.obj == obj && other.name == name && other.args == args && other.block == block
    end

    def clone(&block)
      call = Call.new (obj ? obj.clone(&block) : nil), name, args.map { |arg| arg.clone(&block) }, (self.block ? self.block.clone(&block) : nil)
      call.location = location
      call.name_column_number = name_column_number
      call.name_length = name_length
      block.call(self, call) if block
      call
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

    def initialize(cond, a_then, a_else = nil)
      @cond = cond
      @cond.parent = self
      @then = Expressions.from a_then
      @then.parent = self if @then
      @else = Expressions.from a_else
      @else.parent = self if @else
    end

    def accept_children(visitor)
      self.cond.accept visitor
      self.then.accept visitor
      self.else.accept visitor if self.else
    end

    def ==(other)
      other.is_a?(If) && other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone(&block)
      a_if = If.new cond.clone, self.then.clone(&block), (self.else ? self.else.clone(&block) : nil)
      a_if.location = location
      block.call(self, a_if) if block
      a_if
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
      @target.parent = self
      @value = value
      @value.parent = self
    end

    def accept_children(visitor)
      target.accept visitor
      value.accept visitor
    end

    def ==(other)
      other.is_a?(Assign) && other.target == target && other.value == value
    end

    def clone(&block)
      assign = Assign.new target.clone(&block), value.clone(&block)
      assign.location = location
      block.call(self, assign) if block
      assign
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

    def initialize(cond, body = nil)
      @cond = cond
      @cond.parent = self
      @body = Expressions.from body
      @body.parent = self if @body
    end

    def accept_children(visitor)
      cond.accept visitor
      body.accept visitor
    end

    def ==(other)
      other.is_a?(While) && other.cond == cond && other.body == body
    end

    def clone(&block)
      a_while = While.new cond.clone(&block), (body ? body.clone(&block) : nil)
      a_while.location = location
      block.call(self, a_while) if block
      a_while
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
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self if @body
    end

    def accept_children(visitor)
      args.each { |arg| arg.accept visitor }
      body.accept visitor
    end

    def ==(other)
      other.is_a?(Block) && other.args == args && other.body == body
    end

    def clone(&blk)
      block = Block.new args.map { |arg| arg.clone(&blk) }, (body ? body.clone(&blk) : nil)
      block.location = location
      blk.call(self, block) if blk
      block
    end
  end

  ['return', 'break', 'next', 'yield'].each do |keyword|
    # A #{keyword} expression.
    #
    #     '#{keyword}' [ '(' ')' ]
    #   |
    #     '#{keyword}' '(' arg [ ',' arg ]* ')'
    #   |
    #     '#{keyword}' arg [ ',' arg ]*
    #
    class_eval %Q(
      class #{keyword.capitalize} < ASTNode
        attr_accessor :exps

        def initialize(exps = [])
          @exps = exps
          @exps.each { |exp| exp.parent = self }
        end

        def accept_children(visitor)
          exps.each { |e| e.accept visitor }
        end

        def ==(other)
          other.is_a?(#{keyword.capitalize}) && other.exps == exps
        end

        def clone(&block)
          ret = #{keyword.capitalize}.new exps.clone(&block)
          ret.location = location
          block.call(self, ret) if block
          ret
        end
      end
    )
  end
end
