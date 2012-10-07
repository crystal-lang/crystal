module Crystal
  class Module
    include Enumerable

    attr_accessor :types
    attr_accessor :defs

    def initialize
      @types = {}
      @types["Bool"] = Type.new "Bool", LLVM::Int1
      @types["Int"] = Type.new "Int", LLVM::Int
      @types["Float"] = Type.new "Float", LLVM::Float
      @types["Char"] = Type.new "Char", LLVM::Int8
      @types["String"] = Type.new "String", LLVM::Pointer(char.llvm_type)

      @defs = {}

      define_primitives
    end

    def void
      nil
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

    def string
      @types["String"]
    end

    def each
      yield self
    end
  end
end