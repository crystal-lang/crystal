require "types"

module Crystal
  class Program
    attr_reader :bool
    attr_reader :int
    attr_reader :long
    attr_reader :float
    attr_reader :double
    attr_reader :char
    attr_reader :symbol

    def initialize
      @bool = PrimitiveType.new "Bool"
      @int = PrimitiveType.new "Int"
      @long = PrimitiveType.new "Long"
      @float = PrimitiveType.new "Float"
      @double = PrimitiveType.new "Double"
      @char = PrimitiveType.new "Char"
      @symbol = PrimitiveType.new "Symbol"
    end
  end
end