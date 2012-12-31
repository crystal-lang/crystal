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

    def visit(node : IntLiteral)
      @str << node.value
    end

    def to_s
      @str.to_s
    end
  end
end