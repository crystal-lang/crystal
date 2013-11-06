require "ast"

module Crystal
  class ASTNode
    def to_crystal_node
      visitor = ToCrystalNodeVisitor.new
      accept visitor
      visitor.value
    end
  end

  class ToCrystalNodeVisitor < Visitor
    def visit(node : ASTNode)
      raise "#{node} unsupported in macros"
    end

    def visit(node : NumberLiteral)
      new_node "NumberLiteral", [StringLiteral.new(node.value), SymbolLiteral.new(node.kind.to_s)] of ASTNode
    end

    def visit(node : SymbolLiteral)
      new_node "SymbolLiteral", StringLiteral.new(node.value)
    end

    def visit(node : StringLiteral)
      new_node "StringLiteral", node
    end

    def visit(node : Var)
      new_node "Var", StringLiteral.new(node.name)
    end

    def visit(node : InstanceVar)
      new_node "InstanceVar", StringLiteral.new(node.name)
    end

    # def visit_array_literal(node)
    #   args = []
    #   node.elements.each do |elem|
    #     elem.accept self
    #     args.push @last
    #   end
    #   new_node 'ArrayLiteral', ArrayLiteral.new(args)
    #   false
    # end

    def new_node(name, arg)
      new_node name, [arg] of ASTNode
    end

    def new_node(name, args : Array)
      @last = Call.new(Ident.new(["Crystal", name]), "new", args)
    end

    def value
      @last
    end
  end
end
