module Crystal
  class Module
    attr_accessor :types
    attr_accessor :defs

    def initialize
      @types = {}
      @types["Void"] = Type.new "Void", LLVM.Void
      @types["Bool"] = Type.new "Bool", LLVM::Int1
      @types["Int"] = Type.new "Int", LLVM::Int
      @types["Float"] = Type.new "Float", LLVM::Float
      @types["Char"] = Type.new "Char", LLVM::Int8

      @defs = {}

      define_primitives
    end

    def void
      @types["Void"]
    end

    def int
      @types["Int"]
    end

    def bool
      @types["Bool"]
    end

    def float
      @types["Float"]
    end

    def char
      @types["Char"]
    end
  end
end