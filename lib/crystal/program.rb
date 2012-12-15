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

      define_primitives
      define_builtins options[:load_std]
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

    def define_builtins(load_std)
      if load_std == true
        Dir[File.expand_path("../../../std/**/*.cr",  __FILE__)].each do |file|
          load_std file
        end
      elsif load_std.is_a?(Array)
        load_std.each do |filename|
          load_std File.expand_path("../../../std/#{filename}.cr", __FILE__)
        end
      elsif load_std
        load_std File.expand_path("../../../std/#{load_std}.cr", __FILE__)
      end
    end

    def load_std(file)
      parser = Parser.new File.read(file)
      parser.filename = file
      node = parser.parse
      node.accept TypeVisitor.new(self) if node
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
        require 'dl'
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