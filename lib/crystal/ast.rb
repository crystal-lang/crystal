module Crystal
  class ASTNode
    attr_accessor :line_number
    attr_accessor :parent
  end

  class Expression < ASTNode
  end

  class Expressions < Expression
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
      other.is_a?(Expressions) && other.expressions == expressions
    end

    def clone
      exps = Expressions.new expressions.map(&:clone)
      exps.line_number = line_number
      exps
    end
  end

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
      other.is_a?(ClassDef) && other.name == name && other.body == body && other.superclass == superclass
    end

    def clone
      class_def = ClassDef.new name, body.clone, superclass
      class_def.line_number = line_number
      class_def
    end
  end

  class Nil < Expression
    def accept(visitor)
      visitor.visit_nil self
      visitor.end_visit_nil self
    end

    def ==(other)
      other.is_a?(Nil)
    end

    def clone
      Nil.new
    end
  end

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
      other.is_a?(Bool) && other.value == value
    end

    def clone
      Bool.new value
    end
  end

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
      other.is_a?(Int) && other.value.to_i == value.to_i
    end

    def clone
      Int.new value
    end
  end

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
      other.is_a?(Float) && other.value.to_f == value.to_f
    end

    def clone
      Float.new value
    end
  end

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
      other.is_a?(Char) && other.value.to_i == value.to_i
    end

    def clone
      Char.new value
    end
  end

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
      other.is_a?(Def) && other.receiver == receiver && other.name == name && other.args == args && other.body == body
    end

    def clone
      a_def = Def.new name, args.map(&:clone), body.clone, receiver ? receiver.clone : nil
      a_def.line_number = line_number
      a_def
    end
  end

  class Ref < Expression
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def instance_var?
      @name.start_with? '@'
    end

    def accept(visitor)
      visitor.visit_ref self
      visitor.end_visit_ref self
    end

    def ==(other)
      other.is_a?(Ref) && other.name == name
    end

    def clone
      ref = Ref.new name
      ref.line_number = line_number
      ref
    end
  end

  class Var < ASTNode
    attr_accessor :name

    def initialize(name)
      @name = name
    end

    def constant?
      name[0] == name[0].upcase
    end

    def accept(visitor)
      visitor.visit_var self
      visitor.end_visit_var self
    end

    def ==(other)
      other.is_a?(Var) && other.name == name
    end

    def clone
      var = Var.new name
      var.line_number = line_number
      var
    end
  end

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
      other.is_a?(Call) && other.obj == obj && other.name == name && other.args == args && other.block == block
    end

    def clone
      call = Call.new obj ? obj.clone : nil, name, args.map(&:clone), block ? block.clone : nil
      call.line_number = line_number
      call
    end
  end

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
      other.is_a?(If) && other.cond == cond && other.then == self.then && other.else == self.else
    end

    def clone
      a_if = If.new cond.clone, self.then.clone, self.else.clone
      a_if.line_number = line_number
      a_if
    end
  end

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
      other.is_a?(Assign) && other.target == target && other.value == value
    end

    def clone
      assign = Assign.new target.clone, value.clone
      assign.line_number = line_number
      assign
    end
  end

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
      other.is_a?(While) && other.cond == cond && other.body == body
    end

    def clone
      a_while = While.new cond.clone, body.clone
      a_while.line_number = line_number
      a_while
    end
  end

  class Not < Expression
    attr_accessor :exp

    def initialize(exp)
      @exp = exp
      @exp.parent = self
    end

    def accept(visitor)
      if visitor.visit_not self
        exp.accept visitor
      end
      visitor.end_visit_not self
    end

    def ==(other)
      other.is_a?(Not) && other.exp == exp
    end

    def clone
      a_not = Not.new exp.clone
      a_not.line_number = line_number
      a_not
    end
  end

  class And < Expression
    attr_accessor :left
    attr_accessor :right

    def initialize(left, right)
      @left = left
      @left.parent = self
      @right = right
      @right.parent = self
    end

    def accept(visitor)
      if visitor.visit_and self
        left.accept visitor
        right.accept visitor
      end
      visitor.end_visit_and self
    end

    def ==(other)
      other.is_a?(And) && other.left == left && other.right == right
    end

    def clone
      a_and = And.new left.clone, right.clone
      a_and.line_number = line_number
      a_and
    end
  end

  class Or < Expression
    attr_accessor :left
    attr_accessor :right

    def initialize(left, right)
      @left = left
      @left.parent = self
      @right = right
      @right.parent = self
    end

    def accept(visitor)
      if visitor.visit_and self
        left.accept visitor
        right.accept visitor
      end
      visitor.end_visit_and self
    end

    def ==(other)
      other.is_a?(Or) && other.left == left && other.right == right
    end

    def clone
      a_or = Or.new left.clone, right.clone
      a_or.line_number = line_number
      a_or
    end
  end

  class Block < Expression
    attr_accessor :args
    attr_accessor :body

    def initialize(args, body)
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
      other.is_a?(Block) && other.args == args && other.body == body
    end

    def clone
      block = Block.new args.map(&:clone), body.clone
      block.line_number = line_number
      block
    end
  end

  class Yield < Expression
    attr_accessor :args

    def initialize(args)
      @args = args || []
      @args.each { |arg| arg.parent = self }
    end

    def accept(visitor)
      if visitor.visit_yield self
        args.each { |arg| arg.accept visitor }
      end
      visitor.end_visit_yield self
    end

    def ==(other)
      other.is_a?(Yield) && other.args == args
    end

    def clone
      call = Yield.new args.map(&:clone)
      call.line_number = line_number
      call
    end
  end

  class Return < Expression
    attr_accessor :exp

    def initialize(exp = nil)
      @exp = exp
      @exp.parent = self if @exp
    end

    def accept(visitor)
      if visitor.visit_return self
        @exp.accept visitor if @exp
      end
      visitor.end_visit_return self
    end

    def ==(other)
      other.is_a?(Return) && other.exp == exp
    end

    def clone
      ret = Return.new(exp ? exp.clone : nil)
      ret.line_number = line_number
      ret
    end
  end

  class Next < Expression
    attr_accessor :exp

    def initialize(exp = nil)
      @exp = exp
      @exp.parent = self if @exp
    end

    def accept(visitor)
      if visitor.visit_next self
        @exp.accept visitor if @exp
      end
      visitor.end_visit_next self
    end

    def ==(other)
      other.is_a?(Next) && other.exp == exp
    end

    def clone
      ret = Next.new(exp ? exp.clone : nil)
      ret.line_number = line_number
      ret
    end
  end

  class Break < Expression
    attr_accessor :exp

    def initialize(exp = nil)
      @exp = exp
      @exp.parent = self if @exp
    end

    def accept(visitor)
      if visitor.visit_break self
        @exp.accept visitor if @exp
      end
      visitor.end_visit_break self
    end

    def ==(other)
      other.is_a?(Break) && other.exp == exp
    end

    def clone
      ret = Break.new(exp ? exp.clone : nil)
      ret.line_number = line_number
      ret
    end
  end
end
