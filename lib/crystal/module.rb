module Crystal
  class Module
    include Enumerable

    POINTER_SIZE = 8

    attr_accessor :types
    attr_accessor :defs
    attr_accessor :symbols

    def initialize(options = {})
      @types = {}

      object = @types["Object"] = ObjectType.new "Object"
      value = @types["Value"] = ObjectType.new "Value", object

      @types["Bool"] = PrimitiveType.new "Bool", value, LLVM::Int1, 1
      @types["Char"] = PrimitiveType.new "Char", value, LLVM::Int8, 1
      @types["Int"] = PrimitiveType.new "Int", value, LLVM::Int32, 4
      @types["Long"] = PrimitiveType.new "Long", value, LLVM::Int64, 8
      @types["Float"] = PrimitiveType.new "Float", value, LLVM::Float, 4
      @types["String"] = PrimitiveType.new "String", value, LLVM::Pointer(char.llvm_type), POINTER_SIZE
      @types["Symbol"] = PrimitiveType.new "Symbol", value, LLVM::Int32, 4
      @types["Pointer"] = PrimitiveType.new "Pointer", value, LLVM::Pointer(char.llvm_type), POINTER_SIZE
      @types["Array"] = ArrayType.new object

      @defs = {}
      @symbols = Set.new

      define_primitives
      define_builtins if options[:load_std]
    end

    def void
      nil
    end

    def value
      @types["Value"]
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

    def define_builtins
      Dir[File.expand_path("../../../std/**/*.cr",  __FILE__)].each do |file|
        node = Parser.parse(File.read(file))
        node.accept TypeVisitor.new(self)
      end
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

    def each
      yield self
    end
  end
end