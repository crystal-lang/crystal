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
      @types["Int8"] = PrimitiveType.new "Int8", numeric, LLVM::Int8, 1, self
      @types["Int16"] = PrimitiveType.new "Int16", numeric, LLVM::Int16, 2, self
      @types["Int32"] = PrimitiveType.new "Int32", numeric, LLVM::Int32, 4, self
      @types["Int64"] = PrimitiveType.new "Int64", numeric, LLVM::Int64, 8, self
      @types["UInt8"] = PrimitiveType.new "UInt8", numeric, LLVM::Int8, 1, self
      @types["UInt16"] = PrimitiveType.new "UInt16", numeric, LLVM::Int16, 2, self
      @types["UInt32"] = PrimitiveType.new "UInt32", numeric, LLVM::Int32, 4, self
      @types["UInt64"] = PrimitiveType.new "UInt64", numeric, LLVM::Int64, 8, self
      @types["Float32"] = PrimitiveType.new "Float32", numeric, LLVM::Float, 4, self
      @types["Float64"] = PrimitiveType.new "Float64", numeric, LLVM::Double, 8, self
      @types["Symbol"] = PrimitiveType.new "Symbol", value, LLVM::Int32, 4, self
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
