require "types"
require "llvm"
require "dl"

module Crystal
  make_tuple MacroCacheKey, def_object_id, node_ids

  class Program < NonGenericModuleType
    include DefContainer
    include DefInstanceContainer
    include MatchesLookup
    include ClassVarContainer

    getter symbols
    getter global_vars
    getter macros_cache

    def initialize
      super(self, self, "main")

      @unions = {} of Array(Int32) => Type
      @macros_cache = {} of MacroCacheKey => MacroExpander
      @funs = {} of Array(Int32) => Type

      @types["Object"] = @object = NonGenericClassType.new self, self, "Object", nil
      @object.abstract = true

      @types["Reference"] = @reference = NonGenericClassType.new self, self, "Reference", @object
      @types["Value"] = @value = ValueType.new self, self, "Value", @object
      @types["Number"] = @number = ValueType.new self, self, "Number", @value

      @types["NoReturn"] = @no_return = NoReturnType.new self
      @types["Void"] = @void = VoidType.new self, self, "Void", @value, LLVM::Void, 1
      @types["Nil"] = @nil = NilType.new self, self, "Nil", @value, LLVM::Int1, 1
      @types["Bool"] = @bool = BoolType.new self, self, "Bool", @value, LLVM::Int1, 1
      @types["Char"] = @char = CharType.new self, self, "Char", @value, LLVM::Int8, 1

      @types["Int"] = @int = ValueType.new self, self, "Int", @number
      @int.abstract = true

      @types["Int8"] = @int8 = IntegerType.new self, self, "Int8", @int, LLVM::Int8, 1, 1
      @types["UInt8"] = @uint8 = IntegerType.new self, self, "UInt8", @int, LLVM::Int8, 1, 2
      @types["Int16"] = @int16 = IntegerType.new self, self, "Int16", @int, LLVM::Int16, 2, 3
      @types["UInt16"] = @uint16 = IntegerType.new self, self, "UInt16", @int, LLVM::Int16, 2, 4
      @types["Int32"] = @int32 = IntegerType.new self, self, "Int32", @int, LLVM::Int32, 4, 5
      @types["UInt32"] = @uint32 = IntegerType.new self, self, "UInt32", @int, LLVM::Int32, 4, 6
      @types["Int64"] = @int64 = IntegerType.new self, self, "Int64", @int, LLVM::Int64, 8, 7
      @types["UInt64"] = @uint64 = IntegerType.new self, self, "UInt64", @int, LLVM::Int64, 8, 8

      @types["Float"] = @float = ValueType.new self, self, "Float", @number
      @float.abstract = true

      @types["Float32"] = @float32 = FloatType.new self, self, "Float32", @float, LLVM::Float, 4, 9
      @float32.types["INFINITY"] = Const.new self, @float32, "FLOAT_INFINITY", Primitive.new(:float32_infinity)

      @types["Float64"] = @float64 = FloatType.new self, self, "Float64", @float, LLVM::Double, 8, 10
      @float64.types["INFINITY"] = Const.new self, @float64, "FLOAT_INFINITY", Primitive.new(:float64_infinity)

      @types["Symbol"] = @symbol = SymbolType.new self, self, "Symbol", @value, LLVM::Int32, 4
      @pointer = @types["Pointer"] = PointerType.new self, self, "Pointer", value, ["T"]

      @types["String"] = @string = NonGenericClassType.new self, self, "String", @reference
      @string.instance_vars_in_initialize = Set.new(["@length", "@c"])
      @string.allocated = true

      @string.lookup_instance_var("@length").type = @int32
      @string.lookup_instance_var("@c").type = @char

      @types["Class"] = @class = NonGenericClassType.new self, self, "Class", @reference
      @class.instance_vars_in_initialize = Set.new(["@name"])
      @class.lookup_instance_var("@name").type = @string
      @class.allocated = true

      @types["Array"] = @array = GenericClassType.new self, self, "Array", @reference, ["T"]
      @types["Exception"] = @exception = NonGenericClassType.new self, self, "Exception", @reference

      @types["ARGC_UNSAFE"] = Const.new self, self, "ARGC_UNSAFE", Primitive.new(:argc)
      @types["ARGV_UNSAFE"] = Const.new self, self, "ARGV_UNSAFE", Primitive.new(:argv)

      @types["Math"] = @math = NonGenericModuleType.new self, self, "Math"

      @types["Macro"] = macro_mod = NonGenericModuleType.new self, self, "Macro"
      macro_var = macro_mod.types["Var"] = NonGenericClassType.new self, macro_mod, "Var", @reference
      macro_var.lookup_instance_var("@padding").type = PaddingType.new(self, 24)

      macro_ivar = macro_mod.types["InstanceVar"] = NonGenericClassType.new self, macro_mod, "InstanceVar", @reference
      macro_ivar.lookup_instance_var("@padding").type = PaddingType.new(self, 24)

      @symbols = Set(String).new
      @global_vars = {} of String => Var
      @requires = Set(String).new
      @temp_var_counter = 0
      @type_id_counter = 0
      @nil_var = Var.new("<nil_var>", self.nil)

      define_primitives
    end

    def has_require_flag?(name)
      require_flags.includes?(name)
    end

    def require_flags
      @require_flags ||= begin
        flags = Set(String).new
        exec("uname -m -s").not_nil!.split(' ').each do |uname|
          flags.add uname.downcase
        end
        flags
      end
    end

    class PopenCommand
      include IO

      getter input

      def initialize(command)
        @input = C.popen(command, "r")
        raise Errno.new unless @input
      end

      def close
        C.pclose @input
      end
    end

    def self.exec(command)
      cmd = PopenCommand.new(command)
      begin
        value = cmd.gets.try &.strip
      ensure
        cmd.close
      end
    end

    def exec(command)
      Program.exec(command)
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

    def fun_of(types : Array)
      type_ids = types.map &.type_id
      @funs[type_ids] ||= FunType.new(self, types)
    end

    def require(filename, relative_to = nil)
      if File.exists?(filename) && filename[0] == '/'
        return require_absolute filename
      end

      if relative_to.is_a?(String) && ((single = filename.ends_with?("/*")) || (multi = filename.ends_with?("/**")))
        dir = File.dirname relative_to
        filename_dir_index = filename.rindex('/').not_nil!
        filename_dir = filename[0 .. filename_dir_index]
      #   relative_dir = File.join(dir, $1)
        relative_dir = "#{dir}/#{filename_dir}"
      #   if File.directory?(relative_dir)
        nodes = [] of ASTNode
        require_dir(relative_dir, nodes, multi)
        return Expressions.new(nodes)
      end

      filename = "#{filename}.cr" unless filename.ends_with? ".cr"
      if relative_to.is_a?(String)
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

    def require_dir(dir, nodes, recursive)
      files = [] of String
      dirs = [] of String

      Dir.list(dir) do |filename, type|
        if type == C::DirType::DIR
          if filename != "." && filename != ".." && recursive
            dirs << filename
          end
        else
          if filename.ends_with?(".cr")
            files << "#{dir}/#{filename}"
          end
        end
      end

      files.sort!
      dirs.sort!

      files.each do |file|
        nodes << Require.new(File.expand_path(file))
      end

      dirs.each do |subdir|
        require_dir("#{dir}/#{subdir}", nodes, recursive)
      end

    end

    def require_absolute(file)
      file = "#{Dir.working_directory}/#{file}" unless file.starts_with?('/')
      file = File.expand_path(file)
      # file = File.absolute_path(file)
      return nil if @requires.includes? file

      @requires.add file

      parser = Parser.new File.read(file)
      parser.filename = file
      parser.parse
    end

    def require_from_load_path(file)
      file = File.expand_path("src/#{file}")
      # file = File.expand_path("../../../std/#{file}", __FILE__)
      require_absolute file
    end

    def library_names
      libs = [] of String
      @types.each do |name, type|
        if type.is_a?(LibType) && (libname = type.libname)
          libs << libname
        end
      end
      libs
    end

    def load_libs
      libs = library_names
      if libs.length > 0
        if has_require_flag?("darwin")
          ext = "dylib"
        else
          ext = "so"
        end
        libs.each do |a_lib|
          DL.dlopen "lib#{a_lib}.#{ext}"
        end
      end
    end

    getter :object
    getter :no_return
    getter :value
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
    getter :math
    getter :exception

    def class_type
      @class
    end

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
