module Crystal
  class Module
    include Enumerable

    attr_accessor :types
    attr_accessor :defs

    def initialize
      @types = {}

      object = @types["Object"] = ObjectType.new "Object"
      value = @types["Value"] = ObjectType.new "Value", object

      @types["Bool"] = PrimitiveType.new "Bool", value, LLVM::Int1
      @types["Char"] = PrimitiveType.new "Char", value, LLVM::Int8
      @types["Int"] = PrimitiveType.new "Int", value, LLVM::Int32
      @types["Long"] = PrimitiveType.new "Long", value, LLVM::Int64
      @types["Float"] = PrimitiveType.new "Float", value, LLVM::Float
      @types["String"] = PrimitiveType.new "String", value, LLVM::Pointer(char.llvm_type)

      @defs = {}

      define_primitives
    end

    def void
      nil
    end

    def value
      @types["Value"]
    end

    def object
      @types["Object"]
    end

    def bool
      @types["Bool"]
    end

    def char
      @types["Char"]
    end

    def int
      @types["Int"]
    end

    def long
      @types["Long"]
    end

    def float
      @types["Float"]
    end

    def string
      @types["String"]
    end

    def each
      yield self
    end
  end
end