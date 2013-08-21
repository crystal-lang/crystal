require "types"
require "llvm"

module Crystal
  class Program < NonGenericModuleType
    def initialize
      super("main")

      object = @types["Object"] = NonGenericClassType.new self, "Object", nil
      object.abstract = true

      reference = @types["Reference"] = NonGenericClassType.new self, "Reference", object
      value = @types["Value"] = ValueType.new self, "Value", object
      numeric = @types["Numeric"] = ValueType.new self, "Numeric", value

      @types["Void"] = PrimitiveType.new self, "Void", value, LLVM::Int8, 1
      @types["Nil"] = NilType.new self, "Nil", value, LLVM::Int1, 1
      @types["Bool"] = PrimitiveType.new self, "Bool", value, LLVM::Int1, 1
      @types["Char"] = PrimitiveType.new self, "Char", value, LLVM::Int8, 1

      @types["Int"] = int = ValueType.new self, "Int", numeric
      int.abstract = true

      @types["Int8"] = IntegerType.new self, "Int8", int, LLVM::Int8, 1, 1
      @types["UInt8"] = IntegerType.new self, "UInt8", int, LLVM::Int8, 1, 2
      @types["Int16"] = IntegerType.new self, "Int16", int, LLVM::Int16, 2, 3
      @types["UInt16"] = IntegerType.new self, "UInt16", int, LLVM::Int16, 2, 4
      @types["Int32"] = IntegerType.new self, "Int32", int, LLVM::Int32, 4, 5
      @types["UInt32"] = IntegerType.new self, "UInt32", int, LLVM::Int32, 4, 6
      @types["Int64"] = IntegerType.new self, "Int64", int, LLVM::Int64, 8, 7
      @types["UInt64"] = IntegerType.new self, "UInt64", int, LLVM::Int64, 8, 8

      @types["Float"] = float = ValueType.new self, "Float", numeric
      float.abstract = true

      @types["Float32"] = float32 = FloatType.new self, "Float32", float, LLVM::Float, 4, 9
      # float32.types["INFINITY"] = Const.new float32, "FLOAT_INFINITY", Crystal::FloatInfinity.new(float32)

      @types["Float64"] = float64 = FloatType.new self, "Float64", float, LLVM::Double, 8, 10
      # float64.types["INFINITY"] = Const.new float64, "FLOAT_INFINITY", Crystal::FloatInfinity.new(float64)

      @types["Symbol"] = PrimitiveType.new self, "Symbol", value, LLVM::Int32, 4

      string = @types["String"] = NonGenericClassType.new self, "String", reference
    end

    macro self.type_getter(def_name, type_name)"
      def #{def_name}
        @types[\"#{type_name}\"]
      end
    "end

    macro self.type_getter(name)"
      type_getter :#{name}, :#{name.to_s.capitalize}
    "end

    type_getter :value
    type_getter :nil
    type_getter :object
    type_getter :bool
    type_getter :char
    type_getter :int8
    type_getter :int16
    type_getter :int32
    type_getter :int64
    type_getter :uint8, :UInt8
    type_getter :uint16, :UInt16
    type_getter :uint32, :UInt32
    type_getter :uint64, :UInt64
    type_getter :float32
    type_getter :float64
    type_getter :string
    type_getter :symbol
  end
end
