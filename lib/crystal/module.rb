module Crystal
  class Module
    include Enumerable

    attr_accessor :types
    attr_accessor :defs

    def initialize
      @types = {}

      object = @types["Object"] = ObjectType.new "Object"

      @types["Bool"] = PrimitiveType.new "Bool", object, LLVM::Int1
      @types["Int"] = PrimitiveType.new "Int", object, LLVM::Int
      @types["Float"] = PrimitiveType.new "Float", object, LLVM::Float
      @types["Char"] = PrimitiveType.new "Char", object, LLVM::Int8
      @types["String"] = PrimitiveType.new "String", object, LLVM::Pointer(char.llvm_type)

      @defs = {}

      define_primitives
    end

    def void
      nil
    end

    def object
      @types["Object"]
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