require "llvm"
require "dl"
require "./types"

module Crystal
  class Program < NonGenericModuleType
    include DefContainer
    include DefInstanceContainer
    include MatchesLookup
    include ClassVarContainer

    getter symbols : Set(String)
    getter global_vars : Hash(String, Global)
    getter target_machine : LLVM::TargetMachine?
    getter splat_expansions : Hash(Def, Type)
    getter after_inference_types : Set(Type)
    getter file_modules : Hash(String, FileModule)
    property vars : Hash(String, MetaVar)
    property literal_expander : LiteralExpander?
    property initialized_global_vars : Set(String)
    property? wants_doc : Bool
    property? color : Bool

    @requires : Set(String)
    @temp_var_counter : Int32
    @crystal_path : CrystalPath
    @def_macros : Array(Def)
    @unions : Hash(Array(UInt64), Type)
    @macro_expander : MacroExpander?
    @flags : Set(String)?

    def initialize
      super(self, self, "main")

      @symbols = Set(String).new
      @global_vars = {} of String => Global
      @requires = Set(String).new
      @temp_var_counter = 0
      @crystal_path = CrystalPath.new
      @vars = MetaVars.new
      @def_macros = [] of Def
      @splat_expansions = {} of Def => Type
      @initialized_global_vars = Set(String).new
      @file_modules = {} of String => FileModule
      @unions = {} of Array(UInt64) => Type
      @wants_doc = false
      @color = true
      @after_inference_types = Set(Type).new

      types = @types = {} of String => Type

      types["Object"] = object = @object = NonGenericClassType.new self, self, "Object", nil
      object.allowed_in_generics = false
      object.abstract = true

      types["Reference"] = reference = @reference = NonGenericClassType.new self, self, "Reference", object
      reference.allowed_in_generics = false

      types["Value"] = value = @value = NonGenericClassType.new self, self, "Value", object
      abstract_value_type(value)

      types["Number"] = number = @number = NonGenericClassType.new self, self, "Number", value
      abstract_value_type(number)

      types["NoReturn"] = @no_return = NoReturnType.new self
      types["Void"] = @void = VoidType.new self
      types["Nil"] = nil_t = @nil = NilType.new self, self, "Nil", value, 1
      types["Bool"] = @bool = BoolType.new self, self, "Bool", value, 1
      types["Char"] = @char = CharType.new self, self, "Char", value, 4

      types["Int"] = int = @int = NonGenericClassType.new self, self, "Int", number
      abstract_value_type(int)

      types["Int8"] = @int8 = IntegerType.new self, self, "Int8", int, 1, 1, :i8
      types["UInt8"] = @uint8 = IntegerType.new self, self, "UInt8", int, 1, 2, :u8
      types["Int16"] = @int16 = IntegerType.new self, self, "Int16", int, 2, 3, :i16
      types["UInt16"] = @uint16 = IntegerType.new self, self, "UInt16", int, 2, 4, :u16
      types["Int32"] = @int32 = IntegerType.new self, self, "Int32", int, 4, 5, :i32
      types["UInt32"] = @uint32 = IntegerType.new self, self, "UInt32", int, 4, 6, :u32
      types["Int64"] = @int64 = IntegerType.new self, self, "Int64", int, 8, 7, :i64
      types["UInt64"] = @uint64 = IntegerType.new self, self, "UInt64", int, 8, 8, :u64

      types["Float"] = float = @float = NonGenericClassType.new self, self, "Float", number
      abstract_value_type(float)

      types["Float32"] = @float32 = FloatType.new self, self, "Float32", float, 4, 9
      types["Float64"] = @float64 = FloatType.new self, self, "Float64", float, 8, 10

      types["Symbol"] = @symbol = SymbolType.new self, self, "Symbol", value, 4
      types["Pointer"] = pointer = @pointer = PointerType.new self, self, "Pointer", value, ["T"]
      pointer.struct = true
      pointer.allowed_in_generics = false

      types["Tuple"] = tuple = @tuple = TupleType.new self, self, "Tuple", value, ["T"]
      tuple.allowed_in_generics = false

      types["StaticArray"] = static_array = @static_array = StaticArrayType.new self, self, "StaticArray", value, ["T", "N"]
      static_array.struct = true
      static_array.declare_instance_var("@buffer", Path.new("T"))
      static_array.instance_vars_in_initialize = Set.new(["@buffer"])
      static_array.allocated = true
      static_array.allowed_in_generics = false

      types["String"] = string = @string = NonGenericClassType.new self, self, "String", reference
      string.instance_vars_in_initialize = Set.new(["@bytesize", "@length", "@c"])
      string.allocated = true

      freeze_type string.lookup_instance_var("@bytesize"), @int32
      freeze_type string.lookup_instance_var("@length"), @int32
      freeze_type string.lookup_instance_var("@c"), @uint8

      types["Class"] = klass = @class = MetaclassType.new(self, object, value, "Class")
      object.metaclass = klass
      klass.metaclass = klass
      klass.allocated = true
      klass.allowed_in_generics = false

      types["Array"] = @array = GenericClassType.new self, self, "Array", reference, ["T"]
      types["Exception"] = @exception = NonGenericClassType.new self, self, "Exception", reference

      types["Struct"] = struct_t = @struct_t = NonGenericClassType.new self, self, "Struct", value
      struct_t.abstract = true
      struct_t.struct = true
      struct_t.allowed_in_generics = false

      types["Enum"] = enum_t = @enum = NonGenericClassType.new self, self, "Enum", value
      enum_t.abstract = true
      enum_t.struct = true
      enum_t.allowed_in_generics = false

      types["Proc"] = proc = @proc = FunType.new self, self, "Proc", value, ["T"]
      proc.variadic = true
      proc.allowed_in_generics = false

      types["ARGC_UNSAFE"] = argc_unsafe = Const.new self, self, "ARGC_UNSAFE", Primitive.new(:argc)
      types["ARGV_UNSAFE"] = argv_unsafe = Const.new self, self, "ARGV_UNSAFE", Primitive.new(:argv)

      argc_unsafe.initialized = true
      argv_unsafe.initialized = true

      types["GC"] = gc = NonGenericModuleType.new self, self, "GC"
      gc.metaclass.add_def Def.new("add_finalizer", [Arg.new("object")], Nop.new)

      @literal_expander = LiteralExpander.new self
      @macro_expander = MacroExpander.new self
      @nil_var = Var.new("<nil_var>", nil_t)

      define_primitives
    end

    def add_def(node : Def)
      if file_module = check_private(node)
        file_module.add_def node
      else
        super
      end
    end

    def add_macro(node : Macro)
      if file_module = check_private(node)
        file_module.add_macro node
      else
        super
      end
    end

    def lookup_private_matches(filename, signature)
      file_module?(filename).try &.lookup_matches(signature)
    end

    def file_module?(filename)
      @file_modules[filename]?
    end

    def file_module(filename)
      @file_modules[filename] ||= FileModule.new(self, self, filename)
    end

    def check_private(node)
      return nil unless node.visibility.private?

      location = node.location
      return nil unless location

      filename = location.filename
      return nil unless filename.is_a?(String)

      file_module(filename)
    end

    setter target_machine

    def target_machine
      @target_machine ||= TargetMachine.create(LLVM.default_target_triple, "", false)
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

    def array_of(type)
      array.instantiate [type] of TypeVar
    end

    def tuple_of(types)
      type_vars = types.map { |type| type as TypeVar }
      tuple.instantiate(type_vars)
    end

    def union_of(types : Array)
      case types.size
      when 0
        nil
      when 1
        types.first
      else
        types.sort_by! &.opaque_id
        opaque_ids = types.map(&.opaque_id)
        @unions[opaque_ids] ||= make_union_type(types, opaque_ids)
      end
    end

    def make_union_type(types, opaque_ids)
      # NilType has opaque_id == 0
      has_nil = opaque_ids.first == 0

      if has_nil
        # Check if it's a Nilable type
        if types.size == 2
          other_type = types[1]
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

        # Remove the Nil type now and later insert it at the end
        nil_type = types.shift
      end

      # Sort by name so a same union type, say `Int32 | String`, always is named that
      # way, regardless of the actual order of the types. However, we always put
      # Nil at the end, inside the `nil_type` check.
      types.sort_by! &.to_s

      if nil_type
        types.push nil_type

        if types.all?(&.reference_like?)
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
      type_vars = types.map { |type| type as TypeVar }
      proc.instantiate(type_vars)
    end

    def fun_of(nodes : Array(ASTNode), return_type : Type)
      type_vars = Array(TypeVar).new(nodes.size + 1)
      nodes.each do |node|
        type_vars << node.type
      end
      type_vars << return_type
      proc.instantiate(type_vars)
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

    @class : MetaclassType?
    @proc : FunType?
    @enum : NonGenericClassType?
    @object : NonGenericClassType?
    @reference : NonGenericClassType?
    @value : NonGenericClassType?
    @number : NonGenericClassType?
    @no_return : NoReturnType?
    @void : VoidType?
    @nil : NilType?
    @bool : BoolType?
    @char : CharType?
    @int : NonGenericClassType?
    @int8 : IntegerType?
    @uint8 : IntegerType?
    @int16 : IntegerType?
    @uint16 : IntegerType?
    @int32 : IntegerType?
    @uint32 : IntegerType?
    @int64 : IntegerType?
    @uint64 : IntegerType?
    @float : NonGenericClassType?
    @float32 : FloatType?
    @float64 : FloatType?
    @symbol : SymbolType?
    @pointer : PointerType?
    @tuple : TupleType?
    @static_array : StaticArrayType?
    @nil_var : Var?
    @string : NonGenericClassType?
    @exception : NonGenericClassType?
    @array : GenericClassType?
    @struct_t : NonGenericClassType?

    {% for name in %w(object no_return value number reference void nil bool char int int8 int16 int32 int64
                     uint8 uint16 uint32 uint64 float float32 float64 string symbol pointer array static_array
                     exception tuple proc enum) %}
      def {{name.id}}
        @{{name.id}}.not_nil!
      end
    {% end %}

    getter! literal_expander
    getter! macro_expander

    def struct
      @struct_t.not_nil!
    end

    def class_type
      @class.not_nil!
    end

    getter! :nil_var

    def uint8_pointer
      pointer_of uint8
    end

    def pointer_of(type)
      pointer.instantiate([type] of TypeVar)
    end

    def static_array_of(type, num)
      static_array.instantiate([type, NumberLiteral.new(num)] of TypeVar)
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

    def colorize(obj)
      obj.colorize.toggle(@color)
    end

    private def abstract_value_type(type)
      type.abstract = true
      type.struct = true
      type.allocated = true
      type.allowed_in_generics = false
    end

    private def freeze_type(var, type)
      var.set_type type
      var.freeze_type = type
    end

    def to_s(io)
      io << "<Program>"
    end
  end
end
