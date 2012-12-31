module Crystal
  class Visitor
    def visit_any(node)
    end

    def visit(node)
      true
    end

    def end_visit(node)
    end
  end

  class ASTNode
    def accept(visitor)
      visitor.visit_any self
      if visitor.visit self
        accept_children visitor
      end
      visitor.end_visit self
    end

    def accept_children(visitor)
    end
  end
end