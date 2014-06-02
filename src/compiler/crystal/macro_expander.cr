module Crystal
  class MacroExpander
    def initialize(@mod)
    end

    def expand(a_macro, call)
      visitor = MacroVisitor.new @mod, a_macro, call
      a_macro.body.accept visitor
      visitor.to_s
    end

    def expand(node)
      visitor = MacroVisitor.new @mod
      node.accept visitor
      visitor.to_s
    end

    class MacroVisitor < Visitor
      def self.new(mod, a_macro, call)
        vars = {} of String => ASTNode
        a_macro.args.zip(call.args) do |macro_arg, call_arg|
          vars[macro_arg.name] = call_arg
        end

        new(mod, vars)
      end

      def initialize(@mod, @vars = {} of String => ASTNode)
        @str = StringBuilder.new
        @last = Nop.new
      end

      def visit(node : Expressions)
        node.expressions.each &.accept self
        false
      end

      def visit(node : MacroExpression)
        node.exp.accept self

        if node.exp.is_a?(Var)
          @str << @last.to_macro_id
        else
          @str << @last.to_s
        end
        false
      end

      def visit(node : MacroLiteral)
        @str << node.value
      end

      def visit(node : Var)
        var = @vars[node.name]?
        if var
          @last = var
        else
          node.raise "undefined macro variable '#{node.name}'"
        end
      end

      def visit(node : MacroIf)
        node.cond.accept self

        if @last.truthy?
          node.then.accept self
        else
          node.else.accept self
        end

        false
      end

      def visit(node : MacroFor)
        node.exp.accept self

        exp = @last
        case exp
        when ArrayLiteral
          element_var = node.vars[0]
          index_var = node.vars[1]?

          exp.elements.each_with_index do |element, index|
            @vars[element_var.name] = element
            if index_var
              @vars[index_var.name] = NumberLiteral.new(index, :i32)
            end
            node.body.accept self
          end

          @vars.delete element_var.name
          if index_var
            @vars.delete index_var.name
          end
        else
          node.exp.raise "for expression must be an array, hash or tuple literal"
        end

        false
      end

      def visit(node : Call)
        obj = node.obj
        unless obj
          node.raise "can't execute call without receiver in a macro"
        end

        obj.accept self
        receiver = @last

        args = node.args.map do |arg|
          arg.accept self
          @last
        end

        @last = receiver.interpret(node.name, args)

        false
      end

      def visit(node : BoolLiteral)
        @last = node
      end

      def visit(node : NumberLiteral)
        @last = node
      end

      def visit(node : CharLiteral)
        @last = node
      end

      def visit(node : StringLiteral)
        @last = node
      end

      def visit(node : SymbolLiteral)
        @last = node
      end

      def visit(node : NilLiteral)
        @last = node
      end

      def visit(node : ArrayLiteral)
        @last = node
        false
      end

      def visit(node : Nop)
        @last = node
      end

      def visit(node : ASTNode)
        node.raise "can't execute this in a macro"
      end

      def to_s
        @str.to_s
      end
    end
  end

  class ASTNode
    def to_macro_id
      to_s
    end

    def truthy?
      true
    end

    def interpret(method, args)
      case method
      when "stringify"
        unless args.length == 0
          raise "wrong number of arguments for stringify (#{args.length} for 0)"
        end

        if self.is_a?(StringLiteral)
          self
        else
          StringLiteral.new(to_s)
        end
      when "=="
        BoolLiteral.new(self == args.first)
      when "!="
        BoolLiteral.new(self != args.first)
      else
        raise "undefined macro method: '#{method}'"
      end
    end
  end

  class NilLiteral
    def to_macro_id
      "nil"
    end

    def truthy?
      false
    end
  end

  class BoolLiteral
    def to_macro_id
      @value ? "true" : "false"
    end

    def truthy?
      @value
    end
  end

  class NumberLiteral
    def interpret(method, args)
      case method
      when ">"
        compare_to(args.first) { |me, other| me > other }
      when ">="
        compare_to(args.first) { |me, other| me >= other }
      when "<"
        compare_to(args.first) { |me, other| me < other }
      when "<="
        compare_to(args.first) { |me, other| me <= other }
      else
        super
      end
    end

    def compare_to(other)
      unless other.is_a?(NumberLiteral)
        raise "can't compare number to #{other}"
      end

      BoolLiteral.new(yield to_number, other.to_number)
    end

    def to_number
      @value.to_f64
    end
  end

  class StringLiteral
    def to_macro_id
      @value
    end
  end

  class SymbolLiteral
    def to_macro_id
      @value
    end
  end

  class Var
    def to_macro_id
      @name
    end
  end

  class Call
    def to_macro_id
      if !obj && !block && args.empty?
        @name
      else
        to_s
      end
    end
  end

  class InstanceVar
    def to_macro_id
      @name
    end
  end

  class Path
    def to_macro_id
      @names.join "::"
    end
  end
end
