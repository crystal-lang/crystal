require_relative "types"

module Crystal
  class Program < NonGenericModuleType
    include Enumerable

    POINTER_SIZE = 8

    attr_accessor :symbols
    attr_accessor :global_vars
    attr_accessor :generic_types
    attr_accessor :macros_cache

    def initialize
      super(nil, 'main')

      @unions = {}
      @macros_cache = {}

      object = @types["Object"] = NonGenericClassType.new self, "Object", nil
      value = @types["Value"] = ValueType.new self, "Value", object
      numeric = @types["Numeric"] = ValueType.new self, "Numeric", value

      @types["Void"] = PrimitiveType.new self, "Void", value, LLVM::Int8, 1
      @types["Nil"] = NilType.new self, "Nil", value, LLVM::Int1, 1
      @types["Bool"] = PrimitiveType.new self, "Bool", value, LLVM::Int1, 1
      @types["Char"] = PrimitiveType.new self, "Char", value, LLVM::Int8, 1
      @types["Short"] = PrimitiveType.new self, "Short", value, LLVM::Int16, 2
      @types["Int"] = PrimitiveType.new self, "Int", numeric, LLVM::Int32, 4
      @types["Long"] = PrimitiveType.new self, "Long", numeric, LLVM::Int64, 8
      @types["Float"] = PrimitiveType.new self, "Float", numeric, LLVM::Float, 4
      @types["Double"] = PrimitiveType.new self, "Double", numeric, LLVM::Double, 8
      @types["Symbol"] = PrimitiveType.new self, "Symbol", value, LLVM::Int32, 4
      @types["Pointer"] = PointerType.new self, "Pointer", value, ["T"]

      string = @types["String"] = NonGenericClassType.new self, "String", object
      string.instance_vars_in_initialize = ['@length', '@c']
      string.allocated = true

      string.lookup_instance_var('@length').type = int
      string.lookup_instance_var('@c').type = char

      @types["Array"] = GenericClassType.new self, "Array", object, ["T"]

      @types["ARGC_UNSAFE"] = Const.new self, "ARGC_UNSAFE", Crystal::ARGC.new(int)
      @types["ARGV_UNSAFE"] = Const.new self, "ARGV_UNSAFE", Crystal::ARGV.new(pointer_of(pointer_of(char)))

      @types["Math"] = NonGenericModuleType.new self, "Math"

      @symbols = Set.new
      @global_vars = {}

      @requires = Set.new

      @nil_var = Var.new('nil', self.nil)

      define_primitives
    end

    def program
      self
    end

    def macro_llvm_mod
      @macro_llvm_mod ||= LLVM::Module.new "macros"
    end

    def macro_engine
      @macro_engine ||= LLVM::JITCompiler.new macro_llvm_mod
    end

    def type_merge(*types)
      all_types = types.map! { |type| type.is_a?(UnionType) ? type.types : type }
      all_types.flatten!
      all_types.compact!
      all_types.uniq!(&:type_id)
      combined_union_of *types
    end

    def combined_union_of(*types)
      if types.length == 1
        return types[0]
      end

      combined_types = type_combine *types
      union_of *combined_types
    end

    def union_of(*types)
      types.sort_by!(&:type_id)
      if types.length == 1
        return types[0]
      end

      types_ids = types.map(&:type_id)
      @unions[types_ids] ||= UnionType.new(*types)
    end

    def type_combine(*types)
      all_types = [types.shift]

      types.each do |t2|
        not_found = all_types.each do |t1|
          ancestor = common_ancestor t1, t2
          if ancestor
            all_types.delete t1
            all_types << ancestor.hierarchy_type
            break nil
          end
        end
        if not_found
          all_types << t2
        end
      end

      all_types
    end

    def common_ancestor(t1, t2)
      t1 = t1.base_type if t1.hierarchy?
      t2 = t2.base_type if t2.hierarchy?

      unless t1.class? && t2.class?
        return nil
      end

      depth = [t1.depth, t2.depth].min
      while t1.depth > depth
        t1 = t1.superclass
      end
      while t2.depth > depth
        t2 = t2.superclass
      end

      while !t1.equal?(t2)
        t1 = t1.superclass
        t2 = t2.superclass
      end

      t1.depth == 0 ? nil : t1
    end

    def nil_var
      @nil_var
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

    def array
      @types["Array"]
    end

    def pointer
      @types["Pointer"]
    end

    def char_pointer
      pointer_of @types['Char']
    end

    def pointer_of(type)
      pointer.instantiate [type]
    end

    def array_of(type)
      array.instantiate [type]
    end

    def range_of(a_begin, a_end)
      types["Range"].instantiate [a_begin, a_end]
    end

    def hash_of(key, value)
      types["Hash"].instantiate [key, value]
    end

    def metaclass
      self
    end

    def passed_as_self?
      false
    end

    def require(filename, relative_to = nil)
      if relative_to && (single = filename =~ /(.+)\/\*\Z/ || multi = filename =~ /(.+)\/\*\*\Z/)
        dir = File.dirname relative_to
        relative_dir = File.join(dir, $1)
        if File.directory?(relative_dir)
          nodes = []
          Dir["#{relative_dir}/#{multi ? '**/' : ''}*.cr"].each do |file|
            node = require_absolute(file)
            nodes.push node if node
          end
          return Expressions.new(nodes)
        end
      end

      filename = "#{filename}.cr" unless filename.end_with? ".cr"
      if relative_to
        dir = File.dirname relative_to
        relative_filename = File.join(dir, filename)
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
      file = File.absolute_path(file)
      return nil if @requires.include? file

      @requires.add file

      parser = Parser.new File.read(file)
      parser.filename = file
      node = parser.parse
      node.accept TypeVisitor.new(self) if node
      node
    end

    def require_from_load_path(file)
      require_absolute File.expand_path("../../../std/#{file}", __FILE__)
    end

    def library_names
      libs = []
      @types.values.each do |type|
        if type.is_a?(LibType) && type.libname
          libs << type.libname
        end
      end
      libs
    end

    def load_libs
      libs = library_names
      if libs.length > 0
        Kernel::require 'dl'
        if RUBY_PLATFORM =~ /darwin/
          libs.each do |lib|
            DL.dlopen "lib#{lib}.dylib"
          end
        else
          libs.each do |lib|
            DL.dlopen "lib#{lib}.so"
          end
        end
      end
    end
  end
end