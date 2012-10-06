module Crystal
  class Module
    include Enumerable

    attr_accessor :types
    attr_accessor :defs

    def initialize
      @types = {}
      @types["Bool"] = Type.new "Bool", LLVM::Int1
      @types["Int"] = Type.new "Int", LLVM::Int
      @types["Float"] = Type.new "Float", LLVM::Float
      @types["Char"] = Type.new "Char", LLVM::Int8
      @types["String"] = Type.new "String", LLVM::Pointer(char.llvm_type)

      @defs = {}

      define_primitives
      define_builtins
    end

    def void
      nil
    end

    def int
      @types["Int"]
    end

    def bool
      @types["Bool"]
    end

    def float
      @types["Float"]
    end

    def char
      @types["Char"]
    end

    def string
      @types["String"]
    end

    def each
      yield self
    end

    def define_builtins
      @defs["putn"] = Parser.parse(%Q(
        def putn(n)
          if n > 10
            putn(n / 10)
            putn(n - (n / 10) * 10)
          else
            putchar (n + '0'.ord).chr
          end
        end
      )).first

      string.defs['length'] = Parser.parse(%Q(
        def length
          strlen self
        end
      )).first

      string.defs['to_i'] = Parser.parse(%Q(
        def to_i
          atoi self
        end
      )).first
    end
  end
end