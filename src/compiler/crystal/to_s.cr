require "visitor"

module Crystal
  class ASTNode
    def inspect(io)
      to_s(io)
    end

    def to_s(io)
      visitor = ToSVisitor.new(io)
      self.accept visitor
    end
  end

  class ToSVisitor < Visitor
    def initialize(@str = StringIO.new)
      @indent = 0
      @inside_macro = false
    end

    def visit(node : Primitive)
      @str << "# primitive: "
      @str << node.name
    end

    def visit(node : Nop)
    end

    def visit(node : BoolLiteral)
      @str << decorate_singleton(node, (node.value ? "true" : "false"))
    end

    def visit(node : NumberLiteral)
      @str << node.value
      if node.kind != :i32 && node.kind != :f64
        @str << "_"
        @str << node.kind.to_s
      end
    end

    def visit(node : CharLiteral)
      @str << node.value.inspect
    end

    def visit(node : SymbolLiteral)
      @str << ":" << node.value
    end

    def visit(node : StringLiteral)
      @str << node.value.inspect
    end

    def visit(node : StringInterpolation)
      @str << %(")
      visit_interpolation node, &.replace('"', "\\\"")
      @str << %(")
      false
    end

    def visit_interpolation(node)
      node.expressions.each do |exp|
        if exp.is_a?(StringLiteral)
          @str << yield exp.value.replace('"', "\\\"")
        else
          @str << "\#{"
          exp.accept(self)
          @str << "}"
        end
      end
    end

    def visit(node : ArrayLiteral)
      @str << "["
      node.elements.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end
      @str << "]"
      if of = node.of
        @str << " "
        @str << keyword("of")
        @str << " "
        of.accept self
      end
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
        @str << " "
        @str << keyword("of")
        @str << " "
        of_key.accept self
        @str << " => "
        if (of_value = node.of_value)
          of_value.accept self
        end
      end
      false
    end

    def visit(node : NilLiteral)
      @str << decorate_singleton(node, "nil")
    end

    def visit(node : Expressions)
      if @inside_macro
        node.expressions.each &.accept self
      else
        node.expressions.each do |exp|
          unless exp.nop?
            append_indent
            exp.accept self
            @str << newline
          end
        end
      end
      false
    end

    def visit(node : If)
      visit_if_or_unless "if", node
    end

    def visit(node : Unless)
      visit_if_or_unless "unless", node
    end

    def visit(node : IfDef)
      visit_if_or_unless "ifdef", node
    end

    def visit_if_or_unless(prefix, node)
      @str << keyword(prefix)
      @str << " "
      node.cond.accept self
      @str << newline
      accept_with_indent(node.then)
      unless node.else.nop?
        append_indent
        @str << keyword("else")
        @str << newline
        accept_with_indent(node.else)
      end
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : ClassDef)
      if node.abstract
        @str << keyword("abstract")
        @str << " "
      end
      if node.struct
        @str << keyword("struct")
      else
        @str << keyword("class")
      end
      @str << " "
      node.name.accept self
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
      @str << newline
      accept_with_indent(node.body)

      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : ModuleDef)
      @str << keyword("module")
      @str << " "
      node.name.accept self
      if type_vars = node.type_vars
        @str << "("
        type_vars.each_with_index do |type_var, i|
          @str << ", " if i > 0
          @str << type_var
        end
        @str << ")"
      end
      @str << newline
      accept_with_indent(node.body)

      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : Call)
      node_obj = node.obj
      case node_obj
      when Call
        need_parens = node_obj.args.length > 0
      when Assign
        need_parens = true
      when ArrayLiteral
        need_parens = !!node_obj.of
      when HashLiteral
        need_parens = !!node_obj.of_key
      else
        need_parent = false
      end

      need_parens = (node_obj.is_a?(Call) && node_obj.args.length > 0) ||

      @str << "::" if node.global

      if node_obj && (node.name == "[]" || node.name == "[]?")
        @str << "(" if need_parens
        node_obj.accept self
        @str << ")" if need_parens

        @str << decorate_call(node, "[")

        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end

        if node.name == "[]"
          @str << decorate_call(node, "]")
        else
          @str << decorate_call(node, "]?")
        end
      elsif node_obj && node.name == "[]="
        @str << "(" if need_parens
        node_obj.accept self
        @str << ")" if need_parens

        @str << decorate_call(node, "[")

        node.args[0].accept self
        @str << decorate_call(node, "]")
        @str << " "
        @str << decorate_call(node, "=")
        @str << " "
        node.args[1].accept self
      elsif node_obj && !is_alpha(node.name) && node.args.length == 0
        @str << decorate_call(node, node.name)
        @str << "("
        node_obj.accept self
        @str << ")"
      elsif node_obj && !is_alpha(node.name) && node.args.length == 1
        @str << "(" if need_parens
        node_obj.accept self
        @str << ")" if need_parens

        @str << " "
        @str << decorate_call(node, node.name)
        @str << " "
        node.args[0].accept self
      else
        if node_obj
          @str << "(" if need_parens
          node_obj.accept self
          @str << ")" if need_parens
          @str << "."
        end
        if node.name.ends_with?('=')
          @str << decorate_call(node, node.name[0 .. -2])
          @str << " = "
          node.args.each_with_index do |arg, i|
            @str << ", " if i > 0
            arg.accept self
          end
        else
          @str << decorate_call(node, node.name)

          call_args_need_parens = !node.args.empty? || node.block_arg || node.named_args

          @str << "(" if call_args_need_parens

          printed_arg = false
          node.args.each_with_index do |arg, i|
            @str << ", " if printed_arg
            arg.accept self
            printed_arg = true
          end
          if named_args = node.named_args
            named_args.each do |named_arg|
              @str << ", " if printed_arg
              named_arg.accept self
              printed_arg = true
            end
          end
          if block_arg = node.block_arg
            @str << ", " if printed_arg
            @str << "&"
            block_arg.accept self
          end
          @str << ")" if call_args_need_parens
        end
      end
      if block = node.block
        @str << " "
        block.accept self
      end
      false
    end

    def visit(node : NamedArgument)
      @str << node.name
      @str << ": "
      node.value.accept self
      false
    end

    def visit(node : MacroId)
      @str << node.value
      false
    end

    def visit(node : MacroType)
      node.type.to_s(@str)
      false
    end

    def keyword(str)
      str
    end

    def def_name(str)
      str
    end

    def decorate_singleton(node, str)
      str
    end

    def decorate_call(node, str)
      str
    end

    def decorate_var(node, str)
      str
    end

    def decorate_arg(node, str)
      str
    end

    def decorate_instance_var(node, str)
      str
    end

    def decorate_class_var(node, str)
      str
    end

    def is_alpha(string)
      'a' <= string[0].downcase <= 'z'
    end

    def visit(node : Assign)
      node.target.accept self
      @str << " = "

      value = node.value

      if value.is_a?(Expressions)
        @str << keyword("begin")
        @str << newline
        accept_with_indent(value)
        append_indent
        @str << keyword("end")
      else
        value.accept self
      end

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

    def visit(node : While)
      visit_while_or_until node, "while"
    end

    def visit(node : Until)
      visit_while_or_until node, "until"
    end

    def visit_while_or_until(node, name)
      if node.run_once
        if node.body.is_a?(Expressions)
          @str << keyword("begin")
          @str << newline
          accept_with_indent(node.body)
          append_indent
          @str << keyword("end")
          @str << " "
          @str << keyword(name)
          @str << " "
        else
          node.body.accept self
          @str << " "
          @str << keyword(name)
          @str << " "
        end
        node.cond.accept self
      else
        @str << keyword(name)
        @str << " "
        node.cond.accept self
        @str << newline
        accept_with_indent(node.body)
        append_indent
        @str << keyword("end")
      end
      false
    end

    def visit(node : Out)
      @str << "out "
      node.exp.accept self
      false
    end

    def visit(node : Var)
      @str << decorate_var(node, node.name)
    end

    def visit(node : MetaVar)
      @str << node.name
    end

    def visit(node : FunLiteral)
      @str << "->"
      if node.def.args.length > 0
        @str << "("
        node.def.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")"
      end
      @str << " "
      @str << keyword("do")
      @str << newline
      accept_with_indent(node.def.body)
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : FunPointer)
      @str << "->"
      if obj = node.obj
        obj.accept self
        @str << "."
      end
      @str << node.name

      if node.args.length > 0
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")"
      end
      false
    end

    def visit(node : Def)
      @str << keyword("def")
      @str << " "
      if node_receiver = node.receiver
        node_receiver.accept self
        @str << "."
      end
      @str << def_name(node.name)
      if node.args.length > 0 || node.block_arg
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          @str << "*" if node.splat_index == i
          arg.accept self
        end
        if block_arg = node.block_arg
          @str << ", " if node.args.length > 0
          @str << "&"
          block_arg.accept self
        end
        @str << ")"
      end
      if return_type = node.return_type
        @str << " : "
        return_type.accept self
      end
      @str << newline
      accept_with_indent(node.body)
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : Macro)
      @str << keyword("macro")
      @str << " "
      @str << node.name.to_s
      if node.args.length > 0 || node.block_arg
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        if block_arg = node.block_arg
          @str << ", " if node.args.length > 0
          @str << "&"
          block_arg.accept self
        end
        @str << ")"
      end
      @str << newline

      @inside_macro = true
      accept_with_indent node.body
      @inside_macro = false

      @str << newline
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : MacroExpression)
      @str << "{{"
      node.exp.accept self
      @str << "}}"
      false
    end

    def visit(node : MacroIf)
      @str << "{% if "
      node.cond.accept self
      @str << " }"
      node.then.accept self
      unless node.else.nop?
        @str << "{% else }"
        node.else.accept self
      end
      @str << "{% end }"
      false
    end

    def visit(node : MacroFor)
      @str << "{% for "
      node.vars.each_with_index do |var, i|
        @str << ", " if i > 0
        var.accept self
      end
      @str << " in "
      node.exp.accept self
      @str << " }"
      node.body.accept self
      @str << "{% end }"
      false
    end

    def visit(node : MacroLiteral)
      @str << node.value
      false
    end

    def visit(node : External)
      node.fun_def.try &.accept self
      false
    end

    def visit(node : ExternalVar)
      @str << node.name
      if real_name = node.real_name
        @str << " = "
        @str << real_name
      end
      @str << " : "
      node.type_spec.accept self
      false
    end

    def visit(node : Arg)
      if node.name
        @str << decorate_arg(node, node.name)
      else
        @str << "?"
      end
      if default_value = node.default_value
        @str << " = "
        default_value.accept self
      end
      if restriction = node.restriction
        @str << " : "
        restriction.accept self
      end
      if type = node.type?
        @str << " : "
        type.to_s(@str)
      end
      false
    end

    def visit(node : BlockArg)
      @str << node.name
      if a_fun = node.fun
        @str << " : "
        a_fun.accept self
      end
      false
    end

    def visit(node : Fun)
      if inputs = node.inputs
        inputs.each_with_index do |input, i|
          @str << ", " if i > 0
          input.accept self
        end
        @str << " "
      end
      @str << "-> "
      if output = node.output
        output.accept self
      end
    end

    def visit(node : Self)
      @str << keyword("self")
    end

    def visit(node : Path)
      node.names.each_with_index do |name, i|
        @str << "::" if i > 0 || node.global
        @str << name
      end
    end

    def visit(node : Generic)
      node.name.accept self
      @str << "("
      node.type_vars.each_with_index do |var, i|
        @str << ", " if i > 0
        var.accept self
      end
      @str << ")"
      false
    end

    def visit(node : Underscore)
      @str << "_"
      false
    end

    def visit(node : Splat)
      @str << "*"
      node.exp.accept self
      false
    end

    def visit(node : BackQuote)
      @str << '`'
      exp = node.exp
      case exp
      when StringLiteral
        @str << exp.value.inspect[1 .. -2]
      when StringInterpolation
        visit_interpolation exp, &.replace('`', "\\`")
      end
      @str << '`'
      false
    end

    def visit(node : Union)
      node.types.each_with_index do |ident, i|
        @str << " | " if  i > 0
        ident.accept self
      end
      false
    end

    def visit(node : Virtual)
      node.name.accept self
      @str << "+"
      false
    end

    def visit(node : Metaclass)
      node.name.accept self
      @str << "."
      @str << keyword("class")
      false
    end

    def visit(node : InstanceVar)
      @str << decorate_instance_var(node, node.name)
    end

    def visit(node : ReadInstanceVar)
      node.obj.accept self
      @str << "."
      @str << node.name
      false
    end

    def visit(node : ClassVar)
      @str << decorate_class_var(node, node.name)
    end

    def visit(node : Yield)
      if scope = node.scope
        @str << "with "
        scope.accept self
        @str << " "
      end
      @str << keyword("yield")
      if node.exps.length > 0
        @str << " "
        node.exps.each_with_index do |exp, i|
          @str << ", " if i > 0
          exp.accept self
        end
      end
      false
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
      @str << keyword(keyword)
      if exp = node.exp
        @str << " "
        exp.accept self
      end
      false
    end

    def visit(node : RegexLiteral)
      @str << "/"
      @str << node.value
      @str << "/"
      @str << "i" if (node.modifiers & Regex::IGNORE_CASE) != 0
      @str << "m" if (node.modifiers & Regex::MULTILINE) != 0
      @str << "x" if (node.modifiers & Regex::EXTENDED) != 0
    end

    def visit(node : TupleLiteral)
      @str << "{"
      node.elements.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end
      @str << "}"
      false
    end

    def visit(node : DeclareVar)
      node.var.accept self
      @str << " :: "
      node.declared_type.accept self
      false
    end

    def visit(node : Block)
      @str << keyword("do")

      unless node.args.empty?
        @str << " |"
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << "|"
      end

      @str << newline
      accept_with_indent(node.body)

      append_indent
      @str << keyword("end")

      false
    end

    def visit(node : Include)
      @str << keyword("include")
      @str << " "
      node.name.accept self
      false
    end

    def visit(node : Extend)
      @str << keyword("extend")
      @str << " "
      node.name.accept self
      false
    end

    def visit(node : And)
      to_s_binary node, "&&"
    end

    def visit(node : Or)
      to_s_binary node, "||"
    end

    def visit(node : Not)
      @str << "!"
      node.exp.accept self
      false
    end

    def visit(node : VisibilityModifier)
      @str << node.modifier
      @str << ' '
      node.exp.accept self
      false
    end

    def visit(node : TypeFilteredNode)
      false
    end

    def visit(node : SimpleOr)
      to_s_binary node, keyword("or")
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

    def visit(node : Undef)
      @str << "undef "
      @str << node.name
    end

    def visit(node : LibDef)
      @str << keyword("lib")
      @str << " "
      @str << node.name
      if node.libname
        @str << "('"
        @str << node.libname
        @str << "')"
      end
      @str << newline
      accept_with_indent(node.body)
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : FunDef)
      @str << keyword("fun")
      @str << " "
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
      end
      if body = node.body
        @str << newline
        accept_with_indent body
        @str << newline
        append_indent
        @str << keyword("end")
      end
      false
    end

    def visit(node : TypeDef)
      @str << keyword("type")
      @str << " "
      @str << node.name.to_s
      @str << " : "
      node.type_spec.accept self
      false
    end

    def visit(node : StructDef)
      visit_struct_or_union "struct", node
    end

    def visit(node : UnionDef)
      visit_struct_or_union "union", node
    end

    def visit_struct_or_union(name, node)
      @str << keyword(name)
      @str << " "
      @str << node.name.to_s
      @str << newline
      with_indent do
        node.fields.each do |field|
          append_indent
          field.accept self
          @str << newline
        end
      end
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : EnumDef)
      @str << keyword("enum")
      @str << " "
      @str << node.name.to_s
      if base_type = node.base_type
        @str << " < "
        base_type.accept self
      end
      @str << newline
      with_indent do
        node.constants.each do |constant|
          append_indent
          constant.accept self
          @str << newline
        end
      end
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : RangeLiteral)
      node.from.accept self
      if node.exclusive
        @str << "..."
      else
        @str << ".."
      end
      node.to.accept self
      false
    end

    def visit(node : PointerOf)
      @str << keyword("pointerof")
      @str << "("
      node.exp.accept(self)
      @str << ")"
      false
    end

    def visit(node : SizeOf)
      @str << keyword("sizeof")
      @str << "("
      node.exp.accept(self)
      @str << ")"
      false
    end

    def visit(node : InstanceSizeOf)
      @str << keyword("instance_sizeof")
      @str << "("
      node.exp.accept(self)
      @str << ")"
      false
    end

    def visit(node : IsA)
      node.obj.accept self
      @str << ".is_a?("
      node.const.accept self
      @str << ")"
      false
    end

    def visit(node : Cast)
      node.obj.accept self
      @str << " "
      @str << keyword("as")
      @str << " "
      node.to.accept self
      false
    end

    def visit(node : RespondsTo)
      node.obj.accept self
      @str << ".responds_to?("
      node.name.accept self
      @str << ")"
      false
    end

    def visit(node : Require)
      @str << keyword("require")
      @str << " \""
      @str << node.string
      @str << "\""
      false
    end

    def visit(node : Case)
      @str << keyword("case")
      if cond = node.cond
        @str << " "
        cond.accept self
      end
      @str << newline
      node.whens.each do |wh|
        wh.accept self
      end
      if node_else = node.else
        append_indent
        @str << keyword("else")
        @str << newline
        accept_with_indent node_else
      end
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : When)
      append_indent
      @str << keyword("when")
      @str << " "
      node.conds.each_with_index do |cond, i|
        @str << ", " if i > 0
        cond.accept self
      end
      @str << newline
      accept_with_indent node.body
      false
    end

    def visit(node : ImplicitObj)
      false
    end

    def visit(node : ExceptionHandler)
      @str << keyword("begin")
      @str << newline

      accept_with_indent node.body

      node.rescues.try &.each do |a_rescue|
        append_indent
        a_rescue.accept self
      end

      if node_else = node.else
        append_indent
        @str << keyword("else")
        @str << newline
        accept_with_indent node_else
      end

      if node_ensure = node.ensure
        append_indent
        @str << keyword("ensure")
        @str << newline
        accept_with_indent node_ensure
      end

      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : Rescue)
      @str << keyword("rescue")
      if (types = node.types) && types.length > 0
        @str << " "
        types.each_with_index do |type, i|
          @str << ", " if i > 0
          type.accept self
        end
      end
      if name = node.name
        @str << " => "
        @str << name
      end
      @str << newline
      accept_with_indent node.body
      false
    end

    def visit(node : Alias)
      @str << keyword("alias")
      @str << " "
      @str << node.name
      @str << " = "
      node.value.accept self
      false
    end

    def visit(node : TypeOf)
      @str << keyword("typeof")
      @str << "("
      node.expressions.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end
      @str << ")"
      false
    end

    def visit(node : Attribute)
      @str << "@:"
      @str << node.name
      false
    end

    def newline
      "\n"
    end

    def indent_string
      "  "
    end

    def append_indent
      @indent.times do
        @str << indent_string
      end
    end

    def with_indent
      @indent += 1
      yield
      @indent -= 1
    end

    def accept_with_indent(node : Expressions)
      with_indent do
        node.accept self
      end
    end

    def accept_with_indent(node : Nop)
    end

    def accept_with_indent(node : ASTNode)
      with_indent do
        append_indent
        node.accept self
      end
      @str << newline
    end

    def to_s
      @str.to_s
    end

    def to_s(io)
      @str.to_s(io)
    end
  end
end
