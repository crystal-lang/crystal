require "visitor"

module Crystal
  class ASTNode
    def to_s
      visitor = ToSVisitor.new
      self.accept visitor
      visitor.to_s
    end
  end

  class ToSVisitor < Visitor
    def initialize
      @str = StringBuilder.new
      @indent = 0
    end

    def visit(node : BoolLiteral)
      @str << (node.value ? "true" : "false")
    end

    def visit(node : IntLiteral)
      @str << node.value
    end

    def visit(node : LongLiteral)
      @str << node.value << "L"
    end

    def visit(node : FloatLiteral)
      @str << node.value
    end

    def visit(node : CharLiteral)
      @str << "'" << node.value << "'"
    end

    def visit(node : SymbolLiteral)
      @str << ":" << node.value
    end

    def visit(node : StringLiteral)
      @str << "\"" << node.value << "\""
    end

    def visit(node : ArrayLiteral)
      @str << "["
      node.elements.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end
      @str << "]"
      false
    end

    def visit(node : NilLiteral)
      @str << "nil"
    end

    def visit(node : Expressions)
      node.expressions.each do |exp|
        append_indent
        exp.accept self
        @str << "\n"
      end
      false
    end

    def visit(node : If)
      @str << "if "
      node.cond.accept self
      @str << "\n"
      accept_with_indent(node.then)
      if node.else
        append_indent
        @str << "else\n"
        accept_with_indent(node.else)
      end
      append_indent
      @str << "end"
      false
    end

    def visit(node : Call)
      if node.obj
        node.obj.accept self
        @str << "."
      end
      @str << node.name
      @str << "("
      node.args.each_with_index do |arg, i|
        @str << ", " if i > 0
        arg.accept self
      end
      @str << ")"
      if node.block
        @str << " "
        node.block.accept self
      end
      false
    end

    def visit(node : Assign)
      node.target.accept self
      @str << " = "
      node.value.accept self
      false
    end

    def visit(node : MultiAssign)
      node.targets.each_with_index do |target, i|
        @str << ", " if i > 0
        target.accept self
      end
      @str << " = "
      node.values.each_with_index do |value, i|
        @str << ", " if i > 0
        value.accept self
      end
      false
    end

    def visit(node : Var)
      if node.name
        @str << node.name
      else
        @str << '?'
      end
    end

    def visit(node : Def)
      @str << "def "
      if node.receiver
        node.receiver.accept self
        @str << "."
      end
      @str << node.name.to_s
      if node.args.length > 0
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
      false
    end

    def visit(node : Arg)
      @str << "out " if node.out
      if node.name
        @str << node.name
      else
        @str << "?"
      end
      if node.default_value
        @str << " = "
        node.default_value.accept self
      end
      if node.type_restriction
        @str << " : "
        node.type_restriction.accept self
      end
      false
    end

    def visit(node : SelfRestriction)
      @str << "self"
    end

    def visit(node : Ident)
      node.names.each_with_index do |name, i|
        @str << "::" if i > 0 || node.global
        @str << name
      end
    end

    def visit(node : InstanceVar)
      @str << node.name
    end

    def visit(node : Yield)
      visit_control node, "yield"
    end

    def visit(node : Return)
      visit_control node, "return"
    end

    def visit(node : Break)
      visit_control node, "break"
    end

    def visit(node : Next)
      visit_control node, "next"
    end

    def visit_control(node, keyword)
      @str << keyword
      if node.exps.length > 0
        @str << " "
        node.exps.each_with_index do |exp, i|
          @str << ", " if i > 0
          exp.accept self
        end
      end
      false
    end

    def visit(node : Include)
      @str << "include "
      node.name.accept self
      false
    end

    def append_indent
      @indent.times do
        @str << "  "
      end
    end

    def with_indent
      @indent += 1
      yield
      @indent -= 1
    end

    def accept_with_indent(node : Expressions)
      return unless node
      with_indent do
        node.accept self
      end
    end

    def accept_with_indent(node)
      return unless node
      with_indent do
        append_indent
        node.accept self
      end
      @str << "\n"
    end

    def to_s
      @str.to_s
    end
  end
end