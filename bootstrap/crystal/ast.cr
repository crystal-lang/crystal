module Crystal
  # Base class for nodes in the grammar.
  class ASTNode
    def line_number=(line_number)
      @line_number = line_number
    end

    def line_number
      @line_number
    end

    def column_number=(column_number)
      @column_number = column_number
    end

    def column_number
      @column_number
    end

    def filename=(filename)
      @filename = filename
    end

    def filename
      @filename
    end

    def parent=(parent)
      @parent = parent
    end

    def parent
      @parent
    end

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

    def expressions
      @expressions
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
    def initialize(value)
      @value = value
    end

    def value
      @value
    end

    def ==(other : BoolLiteral)
      other.value == value
    end
  end
end
