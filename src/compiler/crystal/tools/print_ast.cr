require "../syntax/ast"

module Crystal
  def self.print_ast(node)
    node.accept PrintASTVisitor.new
  end

  class PrintASTVisitor < Visitor
    def initialize
      @indents = [] of Bool
    end

    def end_visit(node)
      @indents.pop
    end

    # def visit(node : BoolLiteral)
    #   puts_ast(node, node.value)
    # end

    # def visit(node : NumberLiteral)
    #   puts_ast(node, "#{node.kind} #{node.value}")
    # end

    # def visit(node : CharLiteral)
    #   puts_ast(node, node.value)
    # end

    # def visit(node : StringLiteral)
    #   puts_ast(node, node.value)
    # end

    # # def visit(node : StringInterpolation)
    # #   puts_ast(node, node.value)
    # # end

    # def visit(node : SymbolLiteral)
    #   puts_ast(node, node.value)
    # end

    # def visit(node : ClassDef)
    #   puts_ast(node, node.name)
    # end

    def visit(node : Def)
      puts_ast(node, node.name)
    end

    # def visit(node : Call)
    #   puts_ast(node, node.name)
    # end

    def visit(node : ASTNode)
      str = node.responds_to?(:name) ? node.name : ""
      puts_ast(node, str)
    end

    private def puts_ast(node : ASTNode, str = "")
      unless @indents.empty?
        with_indent { print_indent }
        puts
        print_indent
      end
      print "#{node.class}: #{str} (#{node.location})"
      puts
      @indents.push true
    end

    def print_indent
      unless @indents.empty?
        0.upto(@indents.length - 1) do |i|
          print "   "
        end
      end
    end

    def with_indent
      @indents.push true
      yield
      @indents.pop
    end

  end
end
