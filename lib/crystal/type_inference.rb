module Crystal
  class ASTNode
    attr_accessor :type
  end

  def type(node)
    node.accept TypeVisitor.new
  end

  class TypeVisitor < Visitor
    def initialize
      @vars = {}
    end

    def visit_bool(node)
      node.type = Type::Bool
    end

    def visit_int(node)
      node.type = Type::Int
    end

    def visit_float(node)
      node.type = Type::Float
    end

    def visit_assign(node)
      node.value.accept self
      node.type = node.target.type = node.value.type

      @vars[node.target.name] = node.type

      false
    end

    def visit_var(node)
      node.type = @vars[node.name]
    end

    def end_visit_expressions(node)
      node.type = node.expressions.last.type
    end
  end
end