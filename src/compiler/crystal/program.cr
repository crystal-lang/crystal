require "types"
require "llvm"
require "dl"

module Crystal
  class Program < NonGenericModuleType
    include DefContainer
    include DefInstanceContainer
    include MatchesLookup
    include ClassVarContainer

    getter symbols
    getter global_vars
    getter target_machine
    property vars
    property literal_expander

    def initialize
      super(self, self, "main")

      @unions = {} of Array(Int32) => Type

      @types["Object"] = @object = NonGenericClassType.new self, self, "Object", nil
      @object.abstract = true

      @types["Reference"] = @reference = NonGenericClassType.new self, self, "Reference", @object
      @types["Value"] = @value = ValueType.new self, self, "Value", @object
      @value.abstract = true

      @types["Number"] = @number = ValueType.new self, self, "Number", @value
      @number.abstract = true

      @types["NoReturn"] = @no_return = NoReturnType.new self
      @types["Void"] = @void = VoidType.new self, self, "Void", @value, 1
      @types["Nil"] = @nil = NilType.new self, self, "Nil", @value, 1
      @types["Bool"] = @bool = BoolType.new self, self, "Bool", @value, 1
      @types["Char"] = @char = CharType.new self, self, "Char", @value, 4

      @types["Int"] = @int = ValueType.new self, self, "Int", @number
      @int.abstract = true

      @types["Int8"] = @int8 = IntegerType.new self, self, "Int8", @int, 1, 1, :i8
      @types["UInt8"] = @uint8 = IntegerType.new self, self, "UInt8", @int, 1, 2, :u8
      @types["Int16"] = @int16 = IntegerType.new self, self, "Int16", @int, 2, 3, :i16
      @types["UInt16"] = @uint16 = IntegerType.new self, self, "UInt16", @int, 2, 4, :u16
      @types["Int32"] = @int32 = IntegerType.new self, self, "Int32", @int, 4, 5, :i32
      @types["UInt32"] = @uint32 = IntegerType.new self, self, "UInt32", @int, 4, 6, :u32
      @types["Int64"] = @int64 = IntegerType.new self, self, "Int64", @int, 8, 7, :i64
      @types["UInt64"] = @uint64 = IntegerType.new self, self, "UInt64", @int, 8, 8, :u64

      @types["Float"] = @float = ValueType.new self, self, "Float", @number
      @float.abstract = true

      @types["Float32"] = @float32 = FloatType.new self, self, "Float32", @float, 4, 9
      @types["Float64"] = @float64 = FloatType.new self, self, "Float64", @float, 8, 10

      @types["Symbol"] = @symbol = SymbolType.new self, self, "Symbol", @value, 4
      @types["Pointer"] = @pointer = PointerType.new self, self, "Pointer", @value, ["T"]
      @types["Tuple"] = @tuple = TupleType.new self, self, "Tuple", @value, ["T"]

      @static_array = @types["StaticArray"] = StaticArrayType.new self, self, "StaticArray", @value, ["T", "N"]
      @static_array.struct = true
      @static_array.declare_instance_var("@buffer", Path.new("T"))
      @static_array.instance_vars_in_initialize = Set.new(["@buffer"])
      @static_array.allocated = true

      @types["String"] = @string = NonGenericClassType.new self, self, "String", @reference
      @string.instance_vars_in_initialize = Set.new(["@bytesize", "@length", "@c"])
      @string.allocated = true
      @string.type_id = String::TYPE_ID

      @string.lookup_instance_var("@bytesize").set_type(@int32)
      @string.lookup_instance_var("@length").set_type(@int32)
      @string.lookup_instance_var("@c").set_type(@uint8)

      @types["Class"] = @class = MetaclassType.new(self, @object, @reference, "Class")
      @object.force_metaclass @class
      @class.force_metaclass @class
      @class.instance_vars_in_initialize = Set.new(["@name"])
      @class.lookup_instance_var("@name").set_type(@string)
      @class.allocated = true

      @types["Array"] = @array = GenericClassType.new self, self, "Array", @reference, ["T"]
      @types["Exception"] = @exception = NonGenericClassType.new self, self, "Exception", @reference

      @types["Struct"] = @struct = NonGenericClassType.new self, self, "Struct", @value
      @struct.abstract = true
      @struct.struct = true

      @types["Function"] = @function = FunType.new self, self, "Function", @value, ["T"]
      @function.variadic = true

      @types["ARGC_UNSAFE"] = Const.new self, self, "ARGC_UNSAFE", Primitive.new(:argc)
      @types["ARGV_UNSAFE"] = Const.new self, self, "ARGV_UNSAFE", Primitive.new(:argv)

      @types["GC"] = gc = NonGenericModuleType.new self, self, "GC"
      gc.metaclass.add_def Def.new("add_finalizer", [Arg.new("object")], Nop.new)

      @symbols = Set(String).new
      @global_vars = {} of String => Var
      @requires = Set(String).new
      @temp_var_counter = 0
      @type_id_counter = 1
      @nil_var = Var.new("<nil_var>", @nil)
      @crystal_path = CrystalPath.new
      @vars = MetaVars.new
      @literal_expander = LiteralExpander.new self
      @macro_expander = MacroExpander.new self
      @def_macros = [] of Def

      define_primitives
    end

    setter target_machine

    def target_machine
      @target_machine ||= TargetMachine.create("i686-unknown-linux", "", false)
    end

    def has_flag?(name)
      flags.includes?(name)
    end

    def flags
      @flags ||= host_flags
    end

    def flags=(flags)
      @flags = parse_flags(flags)
    end

    def host_flags
      @host_flags ||= parse_flags(`uname -m -s`)
    end

    def parse_flags(flags_name)
      flags = Set(String).new
      flags_name.split(' ').each do |uname|
        flags.add uname.downcase
      end
      flags
    end

    def add_flag(flag)
      flags.add(flag)
    end

    def program
      self
    end

    def metaclass
      self
    end

    def passed_as_self?
      false
    end

    def next_type_id
      @type_id_counter += 1
    end

    def array_of(type)
      @array.instantiate [type] of TypeVar
    end

    def tuple_of(types)
      @tuple.instantiate types
    end

    def union_of(types : Array)
      case types.length
      when 0
        nil
      when 1
        types.first
      else
        types_ids = types.map(&.type_id).sort!
        @unions[types_ids] ||= make_union_type(types, types_ids)
      end
    end

    def make_union_type(types, types_ids)
      # NilType has type_id == 0
      if types_ids.first == 0
        # Check if it's a Nilable type
        if types.length == 2
          nil_index = types.index(&.nil_type?).not_nil!
          other_index = 1 - nil_index
          other_type = types[other_index]
          if other_type.reference_like? && !other_type.virtual?
            return NilableType.new(self, other_type)
          else
            untyped_type = other_type.remove_typedef
            if untyped_type.fun?
              return NilableFunType.new(self, other_type)
            elsif untyped_type.is_a?(PointerInstanceType)
              return NilablePointerType.new(self, other_type)
            end
          end
        end

        if types.all? &.reference_like?
          return NilableReferenceUnionType.new(self, types)
        else
          return MixedUnionType.new(self, types)
        end
      end

      if types.all? &.reference_like?
        return ReferenceUnionType.new(self, types)
      end

      MixedUnionType.new(self, types)
    end

    def fun_of(types : Array)
      @function.instantiate(types)
    end

    def add_to_requires(filename)
      if @requires.includes? filename
        false
      else
        @requires.add filename
        true
      end
    end

    def find_in_path(filename, relative_to = nil)
      @crystal_path.find filename, relative_to
    end

    def link_attributes
      attrs = [] of LinkAttribute
      add_link_attributes @types, attrs
      attrs
    end

    private def add_link_attributes(types, attrs)
      types.each_value do |type|
        if type.is_a?(LibType) && type.used? && (link_attrs = type.link_attributes)
          attrs.concat link_attrs
        end

        add_link_attributes type.types, attrs
      end
    end

    def load_libs
      if has_flag?("darwin")
        ext = "dylib"
      else
        ext = "so"
      end
      link_attributes.each do |attr|
        if libname = attr.lib
          DL.dlopen "lib#{libname}.#{ext}"
        end
      end
    end

    getter :object
    getter :no_return
    getter :value
    getter :struct
    getter :number
    getter :reference
    getter :void
    getter :nil
    getter :bool
    getter :char
    getter :int
    getter :int8
    getter :int16
    getter :int32
    getter :int64
    getter :uint8
    getter :uint16
    getter :uint32
    getter :uint64
    getter :float
    getter :float32
    getter :float64
    getter :string
    getter :symbol
    getter :pointer
    getter :static_array
    getter :exception
    getter :tuple
    getter :function

    def class_type
      @class
    end

    getter :nil_var

    def uint8_pointer
      pointer_of uint8
    end

    def pointer_of(type)
      @pointer.instantiate([type] of TypeVar)
    end

    def static_array_of(type, num)
      @static_array.instantiate([type, NumberLiteral.new(num)] of TypeVar)
    end

    def new_temp_var
      Var.new(new_temp_var_name)
    end

    def new_temp_var_name
      "__temp_#{@temp_var_counter += 1}"
    end

    def type_desc
      "main"
    end

    def to_s(io)
      io << "<Program>"
    end
  end
end
