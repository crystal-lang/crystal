require "ast"
require "visitor"

module Crystal
  class Interpreter < Visitor
    getter value
    getter mod

    def initialize(@mod)
      @value = PrimitiveValue.new(@mod.nil, nil)
      @vars = {} of String => Value
    end

    def interpret(code)
      parser = Parser.new(code)
      nodes = parser.parse
      nodes.accept self
    end

    def visit(node : ASTNode)
      true
    end

    def visit(node : Nop)
      @value = PrimitiveValue.new(mod.nil, nil)
    end

    def visit(node : NilLiteral)
      @value = PrimitiveValue.new(mod.nil, nil)
    end

    def visit(node : BoolLiteral)
      @value = PrimitiveValue.new(mod.bool, node.value)
    end

    def visit(node : CharLiteral)
      @value = PrimitiveValue.new(mod.char, node.value[0])
    end

    def visit(node : NumberLiteral)
      case node.kind
      when :i8
        type = mod.int8
        value = node.value.to_i8
      when :i16
        type = mod.int16
        value = node.value.to_i16
      when :i32
        type = mod.int32
        value = node.value.to_i32
      when :i64
        type = mod.int64
        value = node.value.to_i64
      when :u8
        type = mod.uint8
        value = node.value.to_u8
      when :u16
        type = mod.uint16
        value = node.value.to_u16
      when :u32
        type = mod.uint32
        value = node.value.to_u32
      when :u64
        type = mod.uint64
        value = node.value.to_u64
      when :f32
        type = mod.float32
        value = node.value.to_f32
      when :f64
        type = mod.float64
        value = node.value.to_f64
      else
        raise "Invalid node kind: #{node.kind}"
      end
      @value = PrimitiveValue.new(type, value)
    end

    def visit(node : StringLiteral)
      @value = ClassValue.new(mod, mod.string,
            {
              "@length" => PrimitiveValue.new(mod.int32, node.value.length)
              "@c" => PrimitiveValue.new(mod.char, node.value[0])
            } of String => Value
          )
    end

    def visit(node : SymbolLiteral)
      @value = PrimitiveValue.new(mod.symbol, node.value)
    end

    def visit(node : Assign)
      target = node.target
      case target
      when Var
        node.value.accept self
        @vars[target.name] = @value
      else
        raise "Assign not implemented yet: #{node.to_s_node}"
      end

      false
    end

    def visit(node : Var)
      @value = @vars[node.name]
    end

    abstract class Value
      getter type

      def initialize(@type)
      end
    end

    class PrimitiveValue < Value
      getter value

      def initialize(type, @value)
        super(type)
      end
    end

    class ClassValue < Value
      def initialize(@mod, type, @vars = {} of String => Value)
        super(type)
      end

      def [](name)
        @vars[name] ||= PrimitiveValue.new(@mod.nil, nil)
      end

      def []=(name, value)
        @vars[name] = value
      end
    end
  end
end
