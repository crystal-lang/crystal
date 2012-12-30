module Crystal
  # Base class for nodes in the grammar.
  class ASTNode
    attr :line_number
    attr :column_number
    attr :filename
    attr :parent

    def location
      [@line_number, @column_number, @filename]
    end

    def location=(location)
      @line_number = location[0]
      @column_number = location[1]
      @filename = location[2]
    end
  end

  # A container for one or many expressions.
  class Expressions < ASTNode
    attr :expressions

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

    def self.from(obj)
      obj
    end

    def initialize(expressions = [])
      @expressions = expressions
      @expressions.each { |e| e.parent = self }
    end
  end

  # The nil literal.
  #
  #     'nil'
  #
  class NilLiteral < ASTNode
    def ==(other : NilLiteral)
      true
    end
  end

  # A bool literal.
  #
  #     'true' | 'false'
  #
  class BoolLiteral < ASTNode
    attr :value

    def initialize(value)
      @value = value
    end

    def ==(other : BoolLiteral)
      other.value == value
    end
  end

  class NumberLiteral < ASTNode
    attr :value
    attr :has_sign
  end

  # An integer literal.
  #
  #     \d+
  #
  class IntLiteral < NumberLiteral
    def initialize(value)
      @value = value.to_i
      @has_sign = value[0] == '+' || value[0] == '-'
    end

    def ==(other : IntLiteral)
      other.value == value
    end
  end

  # A long literal.
  #
  #     \d+L
  #
  class LongLiteral < NumberLiteral
    def initialize(value)
      @has_sign = value[0] == '+' || value[0] == '-'
      @value = value.to_i
    end

    def ==(other : LongLiteral)
      other.value == value
    end
  end

  # A float literal.
  #
  #     \d+.\d+
  #
  class FloatLiteral < NumberLiteral
    def initialize(value)
      @has_sign = value[0] == '+' || value[0] == '-'
      @value = value.to_f
    end

    def ==(other : FloatLiteral)
      other.value == value
    end
  end

  # A char literal.
  #
  #     "'" \w "'"
  #
  class CharLiteral < ASTNode
    attr :value

    def initialize(value)
      @value = value
    end

    def ==(other : CharLiteral)
      other.value == value
    end
  end

  class StringLiteral < ASTNode
    attr :value

    def initialize(value)
      @value = value
    end

    def ==(other : StringLiteral)
      other.value == value
    end
  end
end
