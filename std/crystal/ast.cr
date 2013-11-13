module Crystal
  abstract class ASTNode
  end

  class NilLiteral < ASTNode
    def ==(other : self)
      true
    end

    def to_s
      "nil"
    end
  end

  class BoolLiteral < ASTNode
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

    def to_s
      @value.to_s
    end
  end

  class NumberLiteral < ASTNode
    def initialize(@value : String, @kind)
      @has_sign = value[0] == '+' || value[0] == '-'
    end

    def initialize(value : Number, @kind)
      @value = value.to_s
    end

    def value=(@value)
    end

    def value
      @value
    end

    def kind=(@kind)
      @kind
    end

    def kind
      @kind
    end

    def has_sign=(@has_sign)
    end

    def has_sign
      @has_sign
    end

    def ==(other : self)
      other.value.to_f64 == value.to_f64 && other.kind == kind
    end

    def to_s
      @value.to_s
    end
  end

  class CharLiteral < ASTNode
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

    def to_s
      @value.to_s
    end
  end

  class StringLiteral < ASTNode
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

    def to_s
      @value.to_s
    end
  end

  class SymbolLiteral < ASTNode
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

    def to_s
      @value.to_s
    end
  end

  # # A local variable or block argument.
  class Var < ASTNode
    def initialize(@name)
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

    def to_s
      @name.to_s
    end
  end
end
