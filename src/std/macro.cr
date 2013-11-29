module Macro
  class SymbolLiteral
    def initialize(value)
      @value = value
    end

    def value
      @value
    end

    def to_s
      @value.to_s
    end
  end

  class IntLiteral
    def initialize(value)
      @value = value.to_i
    end

    def value
      @value
    end

    def to_s
      @value.to_s
    end
  end

  class StringLiteral
    def initialize(value)
      @value = value
    end

    def value
      @value
    end

    def to_s
      @value
    end
  end

  class ArrayLiteral(T)
    include Enumerable

    def initialize(elements : Array(T))
      @elements = elements
    end

    def elements
      @elements
    end

    def each
      @elements.each do |elem|
        yield elem
      end
    end
  end

  class Var
    def initialize(name)
      @name = name
    end

    def name
      @name
    end

    def to_s
      @name
    end
  end

  class InstanceVar
    def initialize(name)
      @name = name
    end

    def name
      @name
    end

    def to_s
      @name
    end
  end
end
