module Crystal
  # Base class for nodes in the grammar.
  class ASTNode
    attr_accessor :line_number
    attr_accessor :parent
  end

  # Base class for nodes that are expressions
  class Expression < ASTNode
  end

  # A container for one or many expressions.
  # A method's body and a block's body, for
  # example, are Expressions.
  class Expressions < Expression
    include Enumerable

    attr_accessor :expressions

    def self.from(obj)
      case obj
      when nil
        Expressions.new
      when Expressions
        obj
      when Array
        Expressions.new obj
      else
        Expressions.new [obj]
      end
    end

    def initialize(expressions = nil)
      @expressions = expressions || []
      @expressions.each { |e| e.parent = self }
    end

    def each(&block)
      @expressions.each(&block)
    end

    def [](i)
      @expressions[i]
    end

    def <<(exp)
      exp.parent = self
      @expressions << exp
    end

    def empty?
      @expressions.empty?
    end

    def accept(visitor)
      if visitor.visit_expressions self
        expressions.each { |exp| exp.accept visitor }
      end
      visitor.end_visit_expressions self
    end

    def ==(other)
      other.class == self.class && other.expressions == expressions
    end

    def clone
      exps = self.class.new expressions.map(&:clone)
      exps.line_number = line_number
      exps
    end
  end

  # Class definition:
  #
  #     'class' name [ '<' superclass ]
  #       body
  #     'end'
  #
  class ClassDef < Expression
    attr_accessor :name
    attr_accessor :body
    attr_accessor :superclass

    def initialize(name, body = nil, superclass = nil)
      @name = name
      @body = Expressions.from body
      @body.parent = self
      @superclass = superclass
    end

    def accept(visitor)
      visitor.visit_class_def self
      visitor.end_visit_class_def self
    end

    def ==(other)
      other.class == self.class && other.name == name && other.body == body && other.superclass == superclass
    end

    def clone
      class_def = self.class.new name, body.clone, superclass
      class_def.line_number = line_number
      class_def
    end
  end

  # The nil literal.
  #
  #     'nil'
  #
  class Nil < Expression
    def accept(visitor)
      visitor.visit_nil self
      visitor.end_visit_nil self
    end

    def ==(other)
      other.class == self.class
    end

    def clone
      self.class.new
    end
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class Bool < Expression
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def accept(visitor)
      visitor.visit_bool self
      visitor.end_visit_bool self
    end

    def ==(other)
      other.class == self.class && other.value == value
    end

    def clone
      self.class.new value
    end
  end

  # An integer literal.
  #
  #     \d+
  #
  class Int < Expression
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def has_sign?
      @value[0] == '+' || @value[0] == '-'
    end

    def accept(visitor)
      visitor.visit_int self
      visitor.end_visit_int self
    end

    def ==(other)
      other.class == self.class && other.value.to_i == value.to_i
    end

    def clone
      self.class.new value
    end
  end

  # A float literal.
  #
  #     \d+.\d+
  #
  class Float < Expression
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def has_sign?
      @value[0] == '+' || @value[0] == '-'
    end

    def accept(visitor)
      visitor.visit_float self
      visitor.end_visit_float self
    end

    def ==(other)
      other.class == self.class && other.value.to_f == value.to_f
    end

    def clone
      self.class.new value
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class Char < Expression
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def accept(visitor)
      visitor.visit_char self
      visitor.end_visit_char self
    end

    def ==(other)
      other.class == self.class && other.value.to_i == value.to_i
    end

    def clone
      self.class.new value
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
  class Def < Expression
    attr_accessor :receiver
    attr_accessor :name
    attr_accessor :args
    attr_accessor :body

    def initialize(name, args, body, receiver = nil)
      @name = name
      @args = args
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self
      @receiver = receiver
      @receiver.parent = self if @receiver
    end

    def accept(visitor)
      if visitor.visit_def self
        reciever.accept visitor if receiver
        args.each { |arg| arg.accept visitor }
        body.accept visitor
      end
      visitor.end_visit_def self
    end

    def ==(other)
      other.class == self.class && other.receiver == receiver && other.name == name && other.args == args && other.body == body
    end

    def clone
      a_def = self.class.new name, args.map(&:clone), body.clone, receiver ? receiver.clone : nil
      a_def.line_number = line_number
      a_def
    end
  end

  # A local variable, instance variable, constant,
  # or def or block argument.
  class Var < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def instance_var?
      @name.start_with? '@'
    end

    def constant?
      name[0] == name[0].upcase
    end

    def accept(visitor)
      visitor.visit_var self
      visitor.end_visit_var self
    end

    def ==(other)
      other.class == self.class && other.name == name
    end

    def clone
      var = self.class.new name
      var.line_number = line_number
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
  class Call < Expression
    attr_accessor :obj
    attr_accessor :name
    attr_accessor :args
    attr_accessor :block

    def initialize(obj, name, args = [], block = nil)
      @obj = obj
      @obj.parent = self if @obj
      @name = name
      @args = args || []
      @args.each { |arg| arg.parent = self }
      @block = block
      @block.parent = self if @block
    end

    def accept(visitor)
      if visitor.visit_call self
        obj.accept visitor if obj
        args.each { |arg| arg.accept visitor }
        block.accept visitor if block
      end
      visitor.end_visit_call self
    end

    def ==(other)
      other.class == self.class && other.obj == obj && other.name == name && other.args == args && other.block == block
    end

    def clone
      call = self.class.new obj ? obj.clone : nil, name, args.map(&:clone), block ? block.clone : nil
      call.line_number = line_number
      call
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
  class If < Expression
    attr_accessor :cond
    attr_accessor :then
    attr_accessor :else

    def initialize(cond, a_then, a_else = nil)
      @cond = cond
      @cond.parent = self
      @then = Expressions.from a_then
      @then.parent = self
      @else = Expressions.from a_else
      @else.parent = self
    end

    def accept(visitor)
      if visitor.visit_if self
        self.cond.accept visitor
        self.then.accept visitor
        self.else.accept visitor if self.else
      end
      visitor.end_visit_if self
    end

    def ==(other)
      other.class == self.class && other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone
      a_if = self.class.new cond.clone, self.then.clone, self.else.clone
      a_if.line_number = line_number
      a_if
    end
  end

  # Assign expression.
  #
  #     target '=' value
  #
  class Assign < Expression
    attr_accessor :target
    attr_accessor :value

    def initialize(target, value)
      @target = target
      @target.parent = self
      @value = value
      @value.parent = self
    end

    def accept(visitor)
      if visitor.visit_assign self
        target.accept visitor
        value.accept visitor
      end
      visitor.end_visit_assign self
    end

    def ==(other)
      other.class == self.class && other.target == target && other.value == value
    end

    def clone
      assign = self.class.new target.clone, value.clone
      assign.line_number = line_number
      assign
    end
  end

  # While expression.
  #
  #     'while' cond
  #       body
  #     'end'
  #
  class While < Expression
    attr_accessor :cond
    attr_accessor :body

    def initialize(cond, body = nil)
      @cond = cond
      @cond.parent = self
      @body = Expressions.from body
      @body.parent = self
    end

    def accept(visitor)
      if visitor.visit_while self
        cond.accept visitor
        body.accept visitor
      end
      visitor.end_visit_while self
    end

    def ==(other)
      other.class == self.class && other.cond == cond && other.body == body
    end

    def clone
      a_while = self.class.new cond.clone, body.clone
      a_while.line_number = line_number
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
  class Block < Expression
    attr_accessor :args
    attr_accessor :body

    def initialize(args = [], body = nil)
      @args = args
      @args.each { |arg| arg.parent = self } if @args
      @body = Expressions.from body
      @body.parent = self
    end

    def accept(visitor)
      if visitor.visit_block self
        args.each { |arg| arg.accept visitor }
        body.accept visitor
      end
      visitor.end_visit_block self
    end

    def ==(other)
      other.class == self.class && other.args == args && other.body == body
    end

    def clone
      block = self.class.new args.map(&:clone), body.clone
      block.line_number = line_number
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
      class #{keyword.capitalize} < Expression
        attr_accessor :exps

        def initialize(exps = [])
          @exps = exps
          @exps.each { |exp| exp.parent = self }
        end

        def accept(visitor)
          if visitor.visit_#{keyword} self
            exps.each { |e| e.accept visitor }
          end
          visitor.end_visit_#{keyword} self
        end

        def ==(other)
          other.class == self.class && other.exps == exps
        end

        def clone
          ret = self.class.new exps.clone
          ret.line_number = line_number
          ret
        end
      end
    )
  end
end
