require "types"
require "llvm"

module Crystal
  class Program < ModuleType
    def initialize
      super("main")

      object = @types["Object"] = ObjectType.new "Object", nil, self
      value = @types["Value"] = ObjectType.new "Value", object, self
      numeric = @types["Numeric"] = ObjectType.new "Numeric", value, self

      @types["Void"] = PrimitiveType.new "Void", value, LLVM::Int8, 1, self
      @types["Nil"] = PrimitiveType.new "Nil", value, LLVM::Int1, 1, self
      @types["Bool"] = PrimitiveType.new "Bool", value, LLVM::Int1, 1, self
      @types["Char"] = PrimitiveType.new "Char", value, LLVM::Int8, 1, self
      @types["Short"] = PrimitiveType.new "Short", value, LLVM::Int16, 2, self
      @types["Int"] = PrimitiveType.new "Int", numeric, LLVM::Int32, 4, self
      @types["Long"] = PrimitiveType.new "Long", numeric, LLVM::Int64, 8, self
      @types["Float"] = PrimitiveType.new "Float", numeric, LLVM::Float, 4, self
      @types["Double"] = PrimitiveType.new "Double", numeric, LLVM::Double, 8, self
      @types["Symbol"] = PrimitiveType.new "Symbol", value, LLVM::Int32, 4, self
    end

    def value
      @types["Value"]
    end

    def nil
      @types["Nil"]
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

    def double
      @types["Double"]
    end

    def string
      @types["String"]
    end

    def symbol
      @types["Symbol"]
    end
  end
end