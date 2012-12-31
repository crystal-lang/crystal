require "visitor"

module Crystal
  class ASTNode
    def to_s
      visitor = ToSVisitor.new
      self.accept visitor
      visitor.to_s
    end
  end

  class ToSVisitor < Visitor
    def initialize
      @str = StringBuilder.new
      @indent = 0
    end

    def visit(node : BoolLiteral)
      @str << (node.value ? "true" : "false")
    end

    def visit(node : IntLiteral)
      @str << node.value
    end

    def visit(node : LongLiteral)
      @str << node.value << "L"
    end

    def visit(node : FloatLiteral)
      @str << node.value
    end

    def visit(node : CharLiteral)
      @str << "'" << node.value.chr << "'"
    end

    def visit(node : SymbolLiteral)
      @str << ":" << node.value
    end

    def visit(node : StringLiteral)
      @str << "\"" << node.value << "\""
    end

    def visit(node : ArrayLiteral)
      @str << "["
      node.elements.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end
      @str << "]"
      false
    end

    def visit(node : NilLiteral)
      @str << "nil"
    end

    def to_s
      @str.to_s
    end
  end
end