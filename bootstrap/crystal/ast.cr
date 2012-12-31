module Crystal
  # Base class for nodes in the grammar.
  class ASTNode
    attr :line_number
    attr :column_number
    attr :filename

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
    end

    def ==(other : self)
      other.expressions == expressions
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

    def ==(other : self)
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

    def ==(other : self)
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

    def ==(other : self)
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

    def ==(other : self)
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

    def ==(other : self)
      other.value == value
    end
  end

  class StringLiteral < ASTNode
    attr :value

    def initialize(value)
      @value = value
    end

    def ==(other : self)
      other.value == value
    end
  end

  class SymbolLiteral < ASTNode
    attr_accessor :value

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
    attr_accessor :elements

    def initialize(elements = [])
      @elements = elements
    end

    def ==(other : self)
      other.elements == elements
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
end
