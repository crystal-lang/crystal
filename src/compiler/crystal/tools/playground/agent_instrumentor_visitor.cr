module Crystal
  class Playground::AgentInstrumentorVisitor < Visitor
    property ignore_line

    def initialize(@onlyDef = false)
      @new_nodes = [] of ASTNode
      @ignore_line = nil
    end

    private def instrument(node)
      if (location = node.location) && location.line_number != ignore_line
        Call.new(Global.new("$p"), "i", [node as ASTNode, NumberLiteral.new(location.line_number)])
      else
        node
      end
    end

    private def base_visit(node)
      if @onlyDef
        @new_nodes << node
      else
        @new_nodes << yield node
      end

      false
    end

    def visit(node : Assign)
      base_visit node do |node|
        node.value = instrument(node.value)
        node
      end
    end

    def visit(node : NumberLiteral | StringLiteral | BoolLiteral | CharLiteral | SymbolLiteral | TupleLiteral | ArrayLiteral | StringInterpolation | Var | InstanceVar | ClassVar | Global | TypeOf)
      base_visit node do |node|
        instrument(node)
      end
    end

    def visit(node : Call)
      base_visit node do |node|
        if block = node.block
          block.body = recursive_process(block.body)
        end
        instrument(node)
      end
    end

    def visit(node : Yield)
      base_visit node do |node|
        node.exps[0] = instrument(node.exps[0]) if node.exps.size == 1
        node
      end
    end

    def visit(node : If | Unless)
      base_visit node do |node|
        node.then = recursive_process(node.then)
        node.else = recursive_process(node.else)
        node
      end
    end

    def visit(node : Case)
      base_visit node do |node|
        node.whens.each do |w|
          w.body = recursive_process(w.body)
        end
        if e = node.else
          node.else = recursive_process(e)
        end
        node
      end
    end

    def visit(node : While)
      base_visit node do |node|
        node.body = recursive_process(node.body)
        node
      end
    end

    def visit(node : Return)
      base_visit node do |node|
        if exp = node.exp
          node.exp = instrument(exp)
        end
        node
      end
    end

    def visit(node : Def)
      node.body = recursive_process(node.body, ignore_line = node.location.try(&.line_number))
      @new_nodes << node
      false
    end

    def visit(node : ClassDef | ModuleDef)
      node.body = recursive_process(node.body, onlyDef = true)
      @new_nodes << node
      false
    end

    def visit(node)
      @new_nodes << node
      false
    end

    def recursive_process(node, ignore_line = nil, onlyDef = false)
      visitor = AgentInstrumentorVisitor.new
      visitor.ignore_line = ignore_line
      visitor.process(node)
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
