require "./ast"

module Crystal
  class Visitor
    def visit_any(node)
      true
    end

    # def visit(node)
    #   true
    # end

    def end_visit(node)
    end

    def end_visit_any(node)
    end

    def accept(node)
      node.accept self
    end
  end

  class ASTNode
    def accept(visitor)
      if visitor.visit_any self
        if visitor.visit self
          accept_children visitor
        end
        visitor.end_visit self
        visitor.end_visit_any self
      end
    end

    def accept_children(visitor)
    end
  end
end
