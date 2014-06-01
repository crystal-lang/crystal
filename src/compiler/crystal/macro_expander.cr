module Crystal
  class MacroExpander
    def initialize(@mod)
    end

    def expand(a_macro, call)
      visitor = MacroVisitor.new @mod, a_macro, call
      a_macro.body.accept visitor
      visitor.to_s
    end

    class MacroVisitor < Visitor
      def initialize(@mod, a_macro, call)
        @str = StringBuilder.new
        @vars = {} of String => ASTNode
        a_macro.args.zip(call.args) do |macro_arg, call_arg|
          @vars[macro_arg.name] = call_arg
        end
      end

      def visit(node : MacroExpression)
        node.exp.accept self
        false
      end

      def visit(node : MacroLiteral)
        @str << node.value
      end

      def visit(node : MacroVar)
        var = @vars[node.name]?
        if var
          @str << var.to_s_for_macro
        else
          node.raise "undefined macro variable '#{node.name}'"
        end
      end

      def visit(node : Expressions)
        node.expressions.each &.accept self
        false
      end

      def visit(node : ASTNode)
        node.raise "Bug: unexpected node in macro"
      end

      def to_s
        @str.to_s
      end
    end
  end
end
