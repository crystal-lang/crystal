require_relative 'types'

module Crystal
  class Program < ModuleType
    include Enumerable

    POINTER_SIZE = 8

    attr_accessor :symbols
    attr_accessor :global_vars

    def initialize(options = {})
      super('main')

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
      @types["Symbol"] = PrimitiveType.new "Symbol", value, LLVM::Int32, 4, self
      @types["Pointer"] = PointerType.new value, self

      @types["String"] = ObjectType.new "String", object, self
      string.lookup_instance_var('@c').type = char

      enumerable = @types["Enumerable"] = ModuleType.new "Enumerable", self
      array = @types["Array"] = ObjectType.new "Array", object, self
      array.lookup_instance_var('@length').type = int
      array.lookup_instance_var('@capacity').type = int
      array.lookup_instance_var('@buffer').type = pointer.clone
      array.include enumerable

      string_array = array.clone
      string_array.lookup_instance_var('@buffer').type.var.type = string
      @types["ARGV"] = Const.new "ARGV", Crystal::ARGV.new(string_array), self

      @symbols = Set.new
      @global_vars = {}

      @requires = Set.new

      define_primitives
    end

    def void
      nil
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

    def void_pointer
      @void_pointer ||= begin
        p = pointer.clone
        p.var.type = @types["Void"]
        p
      end
    end

    def passed_as_self?
      false
    end

    def require(filename, relative_to)
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