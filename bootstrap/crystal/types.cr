module Crystal
  class Type
    def to_s
      name
    end
  end

  class PrimitiveType < Type
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end
end