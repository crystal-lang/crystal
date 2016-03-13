module Crystal
  class Playground::AgentInstrumentorTransformer < Transformer
    property ignore_line

    def initialize
      @ignore_line = nil
    end

    private def instrument(node)
      if (location = node.location) && location.line_number != ignore_line
        args = [node as ASTNode, NumberLiteral.new(location.line_number)] of ASTNode
        if node.is_a?(TupleLiteral)
          args << ArrayLiteral.new(node.elements.map { |e| StringLiteral.new(e.to_s) as ASTNode })
        end
        Call.new(Global.new("$p"), "i", args)
      else
        node
      end
    end

    def transform(node : Assign)
      node.value = instrument(node.value)
      node
    end

    def transform(node : NilLiteral | NumberLiteral | StringLiteral | BoolLiteral | CharLiteral | SymbolLiteral | TupleLiteral | ArrayLiteral | StringInterpolation | RegexLiteral | Var | InstanceVar | ClassVar | Global | TypeOf)
      instrument(node)
    end

    def transform(node : Call)
      if node_block = node.block
        node.block = node_block.transform(self)
      end
      instrument(node)
    end

    def transform(node : Yield)
      node.exps[0] = instrument(node.exps[0]) if node.exps.size == 1
      node
    end

    def transform(node : If | Unless)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform(node : Case)
      node.whens.each do |w|
        w.body = w.body.transform(self)
      end
      if e = node.else
        node.else = e.transform(self)
      end
      node
    end

    def transform(node : While)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : Return)
      if exp = node.exp
        node.exp = instrument(exp)
      end
      node
    end

    def transform(node : Def)
      old_ignore_line = @ignore_line
      @ignore_line = node.location.try(&.line_number)
      node.body = node.body.transform(self)
      @ignore_line = old_ignore_line
      node
    end

    def transform(node : ClassDef | ModuleDef)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : Expressions)
      node.expressions = node.expressions.map(&.transform(self) as ASTNode).to_a
      node
    end

    def transform(node : Block)
      node.body = node.body.transform(self)
      node
    end

    def transform(node)
      node
    end
  end
end
