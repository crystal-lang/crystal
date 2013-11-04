require "types"
require "llvm"

module Crystal
  class Program < NonGenericModuleType
    include DefContainer
    include DefInstanceContainer
    include MatchesLookup
    include ClassVarContainer

    getter global_vars

    def initialize
      super(self, self, "main")

      @unions = {} of Array(Int32) => Type

      @object = @types["Object"] = NonGenericClassType.new self, self, "Object", nil
      @object.abstract = true

      @reference = @types["Reference"] = NonGenericClassType.new self, self, "Reference", @object
      @value = @types["Value"] = ValueType.new self, self, "Value", @object
      @number = @types["Number"] = ValueType.new self, self, "Number", @value

      @no_return = @types["NoReturn"] = NoReturnType.new self
      @void = @types["Void"] = PrimitiveType.new self, self, "Void", @value, LLVM::Int8, 1
      @nil = @types["Nil"] = NilType.new self, self, "Nil", @value, LLVM::Int1, 1
      @bool = @types["Bool"] = BoolType.new self, self, "Bool", @value, LLVM::Int1, 1
      @char = @types["Char"] = CharType.new self, self, "Char", @value, LLVM::Int8, 1

      @int = @types["Int"] = ValueType.new self, self, "Int", @number
      @int.abstract = true

      @int8 = @types["Int8"] = IntegerType.new self, self, "Int8", @int, LLVM::Int8, 1, 1
      @uint8 = @types["UInt8"] = IntegerType.new self, self, "UInt8", @int, LLVM::Int8, 1, 2
      @int16 = @types["Int16"] = IntegerType.new self, self, "Int16", @int, LLVM::Int16, 2, 3
      @uint16 = @types["UInt16"] = IntegerType.new self, self, "UInt16", @int, LLVM::Int16, 2, 4
      @int32 = @types["Int32"] = IntegerType.new self, self, "Int32", @int, LLVM::Int32, 4, 5
      @uint32 = @types["UInt32"] = IntegerType.new self, self, "UInt32", @int, LLVM::Int32, 4, 6
      @int64 = @types["Int64"] = IntegerType.new self, self, "Int64", @int, LLVM::Int64, 8, 7
      @uint64 = @types["UInt64"] = IntegerType.new self, self, "UInt64", @int, LLVM::Int64, 8, 8

      @float = @types["Float"] = ValueType.new self, self, "Float", @number
      @float.abstract = true

      @float32 = @types["Float32"] = FloatType.new self, self, "Float32", @float, LLVM::Float, 4, 9
      @float32.types["INFINITY"] = Const.new self, @float32, "FLOAT_INFINITY", Primitive.new(:float32_infinity)

      @float64 = @types["Float64"] = FloatType.new self, self, "Float64", @float, LLVM::Double, 8, 10
      @float64.types["INFINITY"] = Const.new self, @float64, "FLOAT_INFINITY", Primitive.new(:float64_infinity)

      @symbol = @types["Symbol"] = PrimitiveType.new self, self, "Symbol", @value, LLVM::Int32, 4
      @pointer = @types["Pointer"] = PointerType.new self, self, "Pointer", value, ["T"]

      @string = @types["String"] = NonGenericClassType.new self, self, "String", @reference
      @string.instance_vars_in_initialize = Set.new(["@length", "@c"])
      # @string.allocated = true

      @string.lookup_instance_var("@length").type = @int32
      @string.lookup_instance_var("@c").type = @char

      @array = @types["Array"] = GenericClassType.new self, self, "Array", @reference, ["T"]
      @types["Exception"] = NonGenericClassType.new self, self, "Exception", @reference

      @types["ARGC_UNSAFE"] = Const.new self, self, "ARGC_UNSAFE", Primitive.new(:argc)
      @types["ARGV_UNSAFE"] = Const.new self, self, "ARGV_UNSAFE", Primitive.new(:argv)

      @types["Math"] = NonGenericModuleType.new self, self, "Math"

      @global_vars = {} of String => Var
      @requires = Set(String).new
      @temp_var_counter = 0
      @type_id_counter = 0
      @nil_var = Var.new("<nil_var>", self.nil)

      define_primitives
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

    def type_merge(types : Array(Type))
      combined_union_of compact_types(types)
    end

    def type_merge(nodes : Array(ASTNode))
      combined_union_of compact_types(nodes, &.type?)
    end

    def type_merge_union_of(types : Array(Type))
      union_of compact_types(types)
    end

    def compact_types(types)
      compact_types(types) { |type| type }
    end

    def compact_types(objects)
      all_types = Set(Type).new
      objects.each { |obj| add_type all_types, yield(obj) }
      # all_types.delete_if { |type| type.no_return? } if all_types.length > 1
      all_types.to_a
    end

    def add_type(set, type : UnionType)
      type.union_types.each do |subtype|
        add_type set, subtype
      end
    end

    def add_type(set, type : Type)
      set.add type
    end

    def add_type(set, type : Nil)
      # Nothing to do
    end

    def combined_union_of(types : Array)
      case types.length
      when 0
        nil
      when 1
        types.first
      else
        combined_types = type_combine types
        union_of combined_types
      end
    end

    def type_combine(types)
      types
    end

    def array_of(type)
      @array.instantiate [type] of Type
    end

    def union_of(types : Array)
      case types.length
      when 0
        nil
      when 1
        types.first
      else
        types_ids = types.map(&.type_id).sort!

        if types_ids.length == 2 && types_ids[0] == 0 # NilType has type_id == 0
          nil_index = types.index(&.nil_type?).not_nil!
          other_index = 1 - nil_index
          other_type = types[other_index]
          if other_type.class?
            return @unions[types_ids] ||= NilableType.new(self, other_type)
          end
        end

        @unions[types_ids] ||= UnionType.new(self, types)
      end
    end

    def require(filename, relative_to = nil)
      # if File.exists?(filename) && Pathname.new(filename).absolute?
      #   return require_absolute filename
      # end

      # if relative_to && (single = filename =~ /(.+)\/\*\Z/ || multi = filename =~ /(.+)\/\*\*\Z/)
      #   dir = File.dirname relative_to
      #   relative_dir = File.join(dir, $1)
      #   if File.directory?(relative_dir)
      #     nodes = []
      #     Dir["#{relative_dir}/#{multi ? '**/' : ''}*.cr"].sort.each do |file|
      #       node = Require.new(file)
      #       nodes.push node
      #     end
      #     return Expressions.new(nodes)
      #   end
      # end

      filename = "#{filename}.cr" unless filename.ends_with? ".cr"
      if relative_to
        dir = File.dirname relative_to
        # relative_filename = File.join(dir, filename)
        relative_filename = "#{dir}/#{filename}"
        if File.exists?(relative_filename)
          require_absolute relative_filename
        else
          require_from_load_path filename
        end
      else
        require_from_load_path filename
      end
    end

    def require_absolute(file)
      file = "#{Dir.working_directory}/#{file}" unless file.starts_with?('/')
      # file = File.absolute_path(file)
      return nil if @requires.includes? file

      @requires.add file

      parser = Parser.new File.read(file)
      parser.filename = file
      parser.parse
    end

    def require_from_load_path(file)
      file = File.expand_path("std/#{file}")
      # file = File.expand_path("../../../std/#{file}", __FILE__)
      require_absolute file
    end

    def library_names
      libs = [] of String
      @types.each do |name, type|
        if type.is_a?(LibType)
          if libname = type.libname
            libs << libname
          end
        end
      end
      libs
    end

    getter :object
    getter :no_return
    getter :value
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

    getter :nil_var

    def char_pointer
      pointer_of char
    end

    def pointer_of(type)
      @pointer.instantiate([type] of Type)
    end

    def new_temp_var
      Var.new("#temp_#{@temp_var_counter += 1}")
    end

    def to_s
      "<Program>"
    end
  end
end
