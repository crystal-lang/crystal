module Crystal
  class Playground::AgentInstrumentorVisitor < Visitor
    def initialize(@onlyDef = false)
      @new_nodes = [] of ASTNode
    end

    private def instrument(node)
      if location = node.location
        Call.new(Global.new("$p"), "i", [node as ASTNode, NumberLiteral.new(location.line_number)])
      else
        node
      end
    end

    private def base_visit(node)
      if @onlyDef
        @new_nodes << node
        return false
      else
        @new_nodes << yield node
        return false
      end
    end

    def visit(node : Assign)
      base_visit node do |node|
        node.value = instrument(node.value)
        node
      end
    end

    def visit(node : NumberLiteral | StringLiteral | BoolLiteral | CharLiteral | Var | Call)
      base_visit node do |node|
        instrument(node)
      end
    end

    def visit(node : Def)
      node.body = AgentInstrumentorVisitor.new.process(node.body)
      @new_nodes << node
      false
    end

    def visit(node : ClassDef)
      node.body = AgentInstrumentorVisitor.new(onlyDef = true).process(node.body)
      @new_nodes << node
      false
    end

    def visit(node)
      @new_nodes << node
      false
    end

    def process(node : Expressions)
      @new_nodes = [] of ASTNode
      node.accept_children(self)
      node.expressions = @new_nodes
      node
    end

    def process(node)
      process(Expressions.new([node])).expressions.first
    end
  end
end
