require "types"
require "llvm"

module Crystal
  class Program < Type
    include DefContainer
    include DefInstanceContainer
    include MatchesLookup

    def initialize
      # super(nil, "main")
      @types = {} of String => Type

      object = @types["Object"] = NonGenericClassType.new self, "Object", nil
      object.abstract = true

      reference = @types["Reference"] = NonGenericClassType.new self, "Reference", object
      value = @types["Value"] = ValueType.new self, "Value", object
      number = @types["Number"] = ValueType.new self, "Number", value

      @types["Void"] = PrimitiveType.new self, "Void", value, LLVM::Int8, 1
      @types["Nil"] = NilType.new self, "Nil", value, LLVM::Int1, 1
      @types["Bool"] = PrimitiveType.new self, "Bool", value, LLVM::Int1, 1
      @types["Char"] = PrimitiveType.new self, "Char", value, LLVM::Int8, 1

      @types["Int"] = int = ValueType.new self, "Int", number
      int.abstract = true

      @types["Int8"] = IntegerType.new self, "Int8", int, LLVM::Int8, 1, 1
      @types["UInt8"] = IntegerType.new self, "UInt8", int, LLVM::Int8, 1, 2
      @types["Int16"] = IntegerType.new self, "Int16", int, LLVM::Int16, 2, 3
      @types["UInt16"] = IntegerType.new self, "UInt16", int, LLVM::Int16, 2, 4
      @types["Int32"] = IntegerType.new self, "Int32", int, LLVM::Int32, 4, 5
      @types["UInt32"] = IntegerType.new self, "UInt32", int, LLVM::Int32, 4, 6
      @types["Int64"] = IntegerType.new self, "Int64", int, LLVM::Int64, 8, 7
      @types["UInt64"] = IntegerType.new self, "UInt64", int, LLVM::Int64, 8, 8

      @types["Float"] = float = ValueType.new self, "Float", number
      float.abstract = true

      @types["Float32"] = float32 = FloatType.new self, "Float32", float, LLVM::Float, 4, 9
      # float32.types["INFINITY"] = Const.new float32, "FLOAT_INFINITY", Crystal::FloatInfinity.new(float32)

      @types["Float64"] = float64 = FloatType.new self, "Float64", float, LLVM::Double, 8, 10
      # float64.types["INFINITY"] = Const.new float64, "FLOAT_INFINITY", Crystal::FloatInfinity.new(float64)

      @types["Symbol"] = PrimitiveType.new self, "Symbol", value, LLVM::Int32, 4

      # string = @types["String"] = NonGenericClassType.new self, "String", reference
      # HACK: until we have class types in bootstrap
      string = @types["String"] = PrimitiveType.new self, "String", value, LLVM::PointerType.new(LLVM::Int8), 8

      @temp_var_counter = 0
    end

    def program
      self
    end

    def type_merge(types)
      all_types = types #.map! { |type| type.is_a?(UnionType) ? type.types : type }
      # all_types.flatten!
      all_types.compact!
      all_types.uniq! { |t| t.object_id }
      # all_types.delete_if { |type| type.no_return? } if all_types.length > 1
      combined_union_of types
    end

    def combined_union_of(types)
      if types.length == 1
        return types[0]
      end

      raise "Union types are not yet implemented!"
      # combined_types = type_combine *types
      # union_of *combined_types
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

    def new_temp_var
      Var.new("#temp_#{@temp_var_counter += 1}")
    end
  end
end
