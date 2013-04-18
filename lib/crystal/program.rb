require_relative "types"
require_relative "unification"

module Crystal
  class Program < ModuleType
    include Enumerable

    POINTER_SIZE = 8

    attr_accessor :symbols
    attr_accessor :global_vars

    def initialize
      super('main')

      @generic_types = {}

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
      pointer = @types["Pointer"] = PointerType.new value, self
      pointer.type_vars = {"T" => Var.new("T")}

      @types["String"] = ObjectType.new "String", object, self
      string.lookup_instance_var('@length').type = int
      string.lookup_instance_var('@c').type = char

      array = @types["Array"] = ObjectType.new "Array", object, self
      array.type_vars = {"T" => Var.new("T")}

      @types["ARGC_UNSAFE"] = Const.new "ARGC_UNSAFE", Crystal::ARGC.new(int), self
      @types["ARGV_UNSAFE"] = Const.new "ARGV_UNSAFE", Crystal::ARGV.new(pointer_of(pointer_of(char))), self

      @types["Math"] = ModuleType.new "Math", self

      @symbols = Set.new
      @global_vars = {}

      @requires = Set.new

      @nil_var = Var.new('nil', self.nil)

      define_primitives
    end

    def unify(node)
      @unify_visitor ||= UnifyVisitor.new
      Crystal.unify node, @unify_visitor
    end

    def lookup_generic_type(base_class, type_vars)
      key = [base_class.object_id, type_vars.map(&:object_id)]
      unless generic_type = @generic_types[key]
        generic_type = base_class.clone
        i = 0
        generic_type.type_vars.each do |name, var|
          var.type = type_vars[i]
          i += 1
        end
        generic_type.metaclass.defs = base_class.metaclass.defs
        @generic_types[key] = generic_type
      end
      generic_type
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
      p = pointer.clone
      p.var.type = type
      p
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