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

    def visit(node : ASTNode)
    end

    def visit(node : BoolLiteral)
      @str << (node.value ? "true" : "false")
    end

    def visit(node : NumberLiteral)
      @str << node.value
      if node.kind != :i32 && node.kind != :f64
        @str << "_"
        @str << node.kind.to_s
      end
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

    def visit(node : StringInterpolation)
      @str << '"'
      node.expressions.each do |exp|
        if exp.is_a?(StringLiteral)
          @str << exp.value.replace('"', "\\\"")
        else
          @str << "\#{"
          exp.accept(self)
          @str << "}"
        end
      end
      @str << '"'
      false
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

    def visit(node : HashLiteral)
      @str << "{"
      node.keys.each_with_index do |key, i|
        @str << ", " if i > 0
        key.accept self
        @str << " => "
        node.values[i].accept self
      end
      @str << "}"
      if of_key = node.of_key
        @str << " of "
        of_key.accept self
        @str << " => "
        if (of_value = node.of_value)
          of_value.accept self
        end
      end
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

    def visit(node : ClassDef)
      @str << "abstract " if node.abstract
      @str << "class "
      @str << node.name
      if type_vars = node.type_vars
        @str << "("
        type_vars.each_with_index do |type_var, i|
          @str << ", " if i > 0
          @str << type_var.to_s
        end
        @str << ")"
      end
      if superclass = node.superclass
        @str << " < "
        superclass.accept self
      end
      @str << "\n"
      accept_with_indent(node.body)
      @str << "end"
      false
    end

    def visit(node : ModuleDef)
      @str << "module "
      @str << node.name
      if type_vars = node.type_vars
        @str << "("
        type_vars.each_with_index do |type_var, i|
          @str << ", " if i > 0
          @str << type_var
        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      @str << "end"
      false
    end

    def visit(node : Call)
      if node_obj = node.obj
        node_obj.accept self
        @str << "."
      end
      @str << node.name
      @str << "("
      node.args.each_with_index do |arg, i|
        @str << ", " if i > 0
        arg.accept self
      end
      @str << ")"
      if node_block = node.block
        @str << " "
        node_block.accept self
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
      if node_receiver = node.receiver
        node_receiver.accept self
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
      if node_default_value = node.default_value
        @str << " = "
        node_default_value.accept self
      end
      if node_type_restriction = node.type_restriction
        @str << " : "
        node_type_restriction.accept self
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

    def visit(node : NewGenericClass)
      node.name.accept self
      @str << "("
      node.type_vars.each_with_index do |var, i|
        @str << ", " if i > 0
        var.accept self
      end
      @str << ")"
      false
    end

    def visit(node : IdentUnion)
      node.idents.each_with_index do |ident, i|
        @str << " | " if  i > 0
        ident.accept self
      end
      false
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

    def visit(node : Block)
      @str << "do"

      unless node.args.empty?
        @str << " |"
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << "|"
      end

      @str << "\n"
      accept_with_indent(node.body)

      append_indent
      @str << "end"

      false
    end

    def visit(node : Include)
      @str << "include "
      node.name.accept self
      false
    end

    def visit(node : And)
      to_s_binary node, "&&"
    end

    def visit(node : Or)
      to_s_binary node, "||"
    end

    def to_s_binary(node, op)
      node.left.accept self
      @str << " "
      @str << op
      @str << " "
      node.right.accept self
      false
    end

    def visit(node : Global)
      @str << node.name
    end

    def visit(node : LibDef)
      @str << "lib "
      @str << node.name
      if node.libname
        @str << "('"
        @str << node.libname
        @str << "')"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
      false
    end

    def visit(node : FunDef)
      @str << "fun "
      if node.name == node.real_name
        @str << node.name
      else
        @str << node.name
        @str << " = "
        @str << node.real_name
      end
      if node.args.length > 0
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        if node.varargs
          @str << ", ..."
        end
        @str << ")"
      elsif node.varargs
        @str << "(...)"
      end
      if node_return_type = node.return_type
        @str << " : "
        node_return_type.accept self
        node.pointer.times do
          @str << "*"
        end
      end
      false
    end

    def visit(node : FunDefArg)
      @str << node.name.to_s
      @str << " : "
      node.type_spec.accept self
      node.pointer.times do
        @str << "*"
      end
      false
    end

    def visit(node : TypeDef)
      @str << "type "
      @str << node.name.to_s
      @str << " : "
      node.type_spec.accept self
      node.pointer.times do
        @str << "*"
      end
      false
    end

    def visit(node : StructDef)
      visit_struct_or_union "struct", node
    end

    def visit(node : UnionDef)
      visit_struct_or_union "union", node
    end

    def visit_struct_or_union(name, node)
      @str << name
      @str << " "
      @str << node.name.to_s
      @str << "\n"
      with_indent do
        node.fields.each do |field|
          append_indent
          field.accept self
          @str << "\n"
        end
      end
      append_indent
      @str << "end"
      false
    end

    def visit(node : EnumDef)
      @str << "enum "
      @str << node.name.to_s
      @str << "\n"
      with_indent do
        node.constants.each do |constant|
          append_indent
          constant.accept self
          @str << "\n"
        end
      end
      append_indent
      @str << "end"
      false
    end

    def visit(node : RangeLiteral)
      node.from.accept self
      if node.exclusive
        @str << ".."
      else
        @str << "..."
      end
      node.to.accept self
      false
    end

    def visit(node : PointerOf)
      node.var.accept(self)
      @str << ".ptr"
      false
    end

    def visit(node : IsA)
      node.obj.accept self
      @str << ".is_a?("
      node.const.accept self
      @str << ")"
      false
    end

    def visit(node : Require)
      @str << "require \""
      @str << node.string
      @str << "\""
      false
    end

    def visit(node : Case)
      @str << "case "
      node.cond.accept self
      @str << "\n"
      node.whens.each do |wh|
        wh.accept self
      end
      if node_else = node.else
        @str << "else\n"
        accept_with_indent node_else
      end
      @str << "end"
      false
    end

    def visit(node : When)
      @str << "when "
      node.conds.each_with_index do |cond, i|
        @str << ", " if i > 0
        cond.accept self
      end
      @str << "\n"
      accept_with_indent node.body
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
      if node
        with_indent do
          node.accept self
        end
      end
    end

    def accept_with_indent(node)
      if node
        with_indent do
          append_indent
          node.accept self
        end
      end
      @str << "\n"
    end

    def to_s
      @str.to_s
    end
  end
end
