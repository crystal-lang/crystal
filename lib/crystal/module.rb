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
      @types["Int"] = PrimitiveType.new "Int", value, LLVM::Int
      @types["Float"] = PrimitiveType.new "Float", value, LLVM::Float
      @types["Char"] = PrimitiveType.new "Char", value, LLVM::Int8
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