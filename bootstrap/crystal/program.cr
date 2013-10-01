require "types"
require "llvm"

module Crystal
  class Program < Type
    include DefContainer
    include DefInstanceContainer
    include MatchesLookup

    getter :types

    def initialize
      # super(nil, "main")
      @types = {} of String => Type
      @unions = {} of Array(UInt64) => UnionType

      object = @types["Object"] = NonGenericClassType.new self, self, "Object", nil
      object.abstract = true

      reference = @types["Reference"] = NonGenericClassType.new self, self, "Reference", object
      value = @types["Value"] = ValueType.new self, self, "Value", object
      number = @types["Number"] = ValueType.new self, self, "Number", value

      @types["Void"] = PrimitiveType.new self, self, "Void", value, LLVM::Int8, 1
      @types["Nil"] = NilType.new self, self, "Nil", value, LLVM::Int1, 1
      @types["Bool"] = PrimitiveType.new self, self, "Bool", value, LLVM::Int1, 1
      @types["Char"] = PrimitiveType.new self, self, "Char", value, LLVM::Int8, 1

      @types["Int"] = int = ValueType.new self, self, "Int", number
      int.abstract = true

      @types["Int8"] = IntegerType.new self, self, "Int8", int, LLVM::Int8, 1, 1
      @types["UInt8"] = IntegerType.new self, self, "UInt8", int, LLVM::Int8, 1, 2
      @types["Int16"] = IntegerType.new self, self, "Int16", int, LLVM::Int16, 2, 3
      @types["UInt16"] = IntegerType.new self, self, "UInt16", int, LLVM::Int16, 2, 4
      @types["Int32"] = IntegerType.new self, self, "Int32", int, LLVM::Int32, 4, 5
      @types["UInt32"] = IntegerType.new self, self, "UInt32", int, LLVM::Int32, 4, 6
      @types["Int64"] = IntegerType.new self, self, "Int64", int, LLVM::Int64, 8, 7
      @types["UInt64"] = IntegerType.new self, self, "UInt64", int, LLVM::Int64, 8, 8

      @types["Float"] = float = ValueType.new self, self, "Float", number
      float.abstract = true

      @types["Float32"] = float32 = FloatType.new self, self, "Float32", float, LLVM::Float, 4, 9
      # float32.types["INFINITY"] = Const.new float32, "FLOAT_INFINITY", Crystal::FloatInfinity.new(float32)

      @types["Float64"] = float64 = FloatType.new self, self, "Float64", float, LLVM::Double, 8, 10
      # float64.types["INFINITY"] = Const.new float64, "FLOAT_INFINITY", Crystal::FloatInfinity.new(float64)

      @types["Symbol"] = PrimitiveType.new self, self, "Symbol", value, LLVM::Int32, 4

      # string = @types["String"] = NonGenericClassType.new self, "String", reference
      # HACK: until we have class types in bootstrap
      string = @types["String"] = PrimitiveType.new self, self, "String", value, LLVM::PointerType.new(LLVM::Int8), 8

      @temp_var_counter = 0

      define_primitives
    end

    def program
      self
    end

    def passed_as_self?
      false
    end

    def lookup_type(names, already_looked_up = Set(UInt64).new, lookup_in_container = true)
      return nil if already_looked_up.includes?(type_id)

      if lookup_in_container
        already_looked_up.add(type_id)
      end

      type = self
      names.each do |name|
        type = type.try! &.types[name]?
        break unless type
      end

      type
    end

    def type_merge(types)
      all_types = types #.map! { |type| type.is_a?(UnionType) ? type.types : type }
      # all_types.flatten!
      not_nil_types = [] of Type
      all_types.compact not_nil_types

      not_nil_types.uniq! &.type_id
      # all_types.delete_if { |type| type.no_return? } if all_types.length > 1
      combined_union_of not_nil_types
    end

    def combined_union_of(types)
      if types.length == 1
        return types[0]
      end

      combined_types = type_combine types
      union_of combined_types
    end

    def type_combine(types)
      types
    end

    def union_of(type1, type2)
      union_of [type1, type2]
    end

    def union_of(types : Array)
      if types.length == 1
        return types[0]
      end

      # types.sort_by! &.type_id
      types_ids = types.map &.type_id
      @unions.fetch_or_assign(types_ids) { UnionType.new self, types }
    end

    macro self.type_getter(def_name, type_name)"
      def #{def_name}
        @types[\"#{type_name}\"]
      end
    "end

    macro self.type_getter(name)"
      type_getter :#{name}, :#{name.to_s.capitalize}
    "end

    type_getter :object
    type_getter :value
    type_getter :reference
    type_getter :void
    type_getter :nil
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

    def to_s
      "<Program>"
    end
  end
end
