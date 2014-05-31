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
      def initialize(@mod, @macro, @call)
        @str = StringBuilder.new
      end

      def visit(node : MacroLiteral)
        @str << node.value
      end

      def visit(node : MacroVar)
        index = @macro.args.index { |arg| arg.name == node.name }
        if index
          @str << @call.args[index].to_s_for_macro
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
