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

    def to_s_node
      to_s
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

    def to_s_node
      to_s
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

    def to_s_node
      to_s
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

    def to_s_node
      to_s
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

    def to_s_node
      to_s
    end
  end
end
