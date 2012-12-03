module Crystal
  class ASTNode
    def to_crystal
      visitor = ToCrystalVisitor.new
      accept visitor
      visitor.value
    end
  end

  class ToCrystalVisitor < Visitor
    def visit_int_literal(node)
      new_node 'IntLiteral', node
    end

    def visit_symbol_literal(node)
      new_node 'SymbolLiteral', node
    end

    def visit_string_literal(node)
      new_node 'StringLiteral', node
    end

    def visit_var(node)
      new_node 'Var', StringLiteral.new(node.name)
    end

    def visit_array_literal(node)
      args = []
      node.elements.each do |elem|
        elem.accept self
        args.push @last
      end
      new_node 'ArrayLiteral', ArrayLiteral.new(args)
      false
    end

    def new_node(name, *args)
      @last = Call.new(Ident.new(['Crystal', name]), 'new', args)
    end

    def value
      @last
    end
  end
end