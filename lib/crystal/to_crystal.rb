require_relative 'ast'

module Crystal
  class ASTNode
    def to_crystal_node
      visitor = ToCrystalNodeVisitor.new
      accept visitor
      visitor.value
    end
  end

  class ToCrystalNodeVisitor < Visitor
    def visit_int_literal(node)
      new_node 'IntLiteral', node
    end

    def visit_symbol_literal(node)
      new_node 'SymbolLiteral', StringLiteral.new(node.value.to_s)
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

  class ASTNode
    def to_crystal_binary
      visitor = ToCrystalBinaryVisitor.new
      accept visitor
      visitor.value
    end
  end

  class ToCrystalBinaryVisitor < Visitor
    def visit_int_literal(node)
      ptr = FFI::MemoryPointer.new(:int, 1)
      ptr.put_int32(0, node.value.to_i)
      @last = ptr
    end

    def visit_symbol_literal(node)
      @last = pointer(string(node.value))
    end

    def visit_string_literal(node)
      @last = pointer(string(node.value))
    end

    def visit_var(node)
      @last = pointer(string(node.name))
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

    def string(str)
      string_ptr = FFI::MemoryPointer.new(:char, str.length + 5)
      string_ptr.put_int32(0, str.length)
      string_ptr.put_string(4, str)
      string_ptr
    end

    def pointer(other)
      ptr = FFI::MemoryPointer.new(:pointer, 1)
      ptr.put_pointer(0, other)
      ptr
    end

    def value
      @last
    end
  end
end
