require "./ast"
require "./visitor"

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
    @str : IO
    @indent : Int32
    @inside_macro : Int32
    @inside_lib : Bool
    @inside_struct_or_union : Bool

    def initialize(@str = MemoryIO.new)
      @indent = 0
      @inside_macro = 0
      @inside_lib = false
      @inside_struct_or_union = false
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
      node.value.inspect(@str)
    end

    def visit(node : SymbolLiteral)
      @str << ':'

      value = node.value
      if Symbol.needs_quotes?(value)
        value.inspect(@str)
      else
        value.to_s(@str)
      end
    end

    def visit(node : StringLiteral)
      node.value.inspect(@str)
    end

    def visit(node : StringInterpolation)
      @str << %(")
      visit_interpolation node, &.gsub('"', "\\\"")
      @str << %(")
      false
    end

    def visit_interpolation(node)
      node.expressions.each do |exp|
        if exp.is_a?(StringLiteral)
          @str << yield exp.value.gsub('"', "\\\"")
        else
          @str << "\#{"
          exp.accept(self)
          @str << "}"
        end
      end
    end

    def visit(node : ArrayLiteral)
      name = node.name
      if name
        name.accept self
        @str << " {"
      else
        @str << "["
      end

      node.elements.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end

      if name
        @str << "}"
      else
        @str << "]"
      end

      if of = node.of
        @str << " "
        @str << keyword("of")
        @str << " "
        of.accept self
      end
      false
    end

    def visit(node : HashLiteral)
      if name = node.name
        name.accept self
        @str << " "
      end

      @str << "{"
      node.entries.each_with_index do |entry, i|
        @str << ", " if i > 0
        entry.key.accept self
        @str << " => "
        entry.value.accept self
      end
      @str << "}"
      if of = node.of
        @str << " "
        @str << keyword("of")
        @str << " "
        of.key.accept self
        @str << " => "
        of.value.accept self
      end
      false
    end

    def visit(node : NilLiteral)
      @str << decorate_singleton(node, "nil")
    end

    def visit(node : Expressions)
      if @inside_macro > 0
        node.expressions.each &.accept self
      else
        node.expressions.each do |exp|
          unless exp.nop?
            append_indent
            exp.accept self
            newline
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
      newline
      accept_with_indent(node.then)
      unless node.else.nop?
        append_indent
        @str << keyword("else")
        newline
        accept_with_indent(node.else)
      end
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : ClassDef)
      if node.abstract?
        @str << keyword("abstract")
        @str << " "
      end
      @str << keyword(node.struct? ? "struct" : "class")
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
      newline
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
      newline
      accept_with_indent(node.body)

      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : Call)
      visit_call node
    end

    def visit_call(node, ignore_obj = false)
      if node.name == "`"
        visit_backtick(node.args[0])
        return false
      end

      node_obj = ignore_obj ? nil : node.obj

      need_parens = need_parens(node_obj)
      call_args_need_parens = false

      @str << "::" if node.global

      if node_obj && (node.name == "[]" || node.name == "[]?")
        in_parenthesis(need_parens, node_obj)

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
        in_parenthesis(need_parens, node_obj)

        @str << decorate_call(node, "[")

        node.args[0].accept self
        @str << decorate_call(node, "]")
        @str << " "
        @str << decorate_call(node, "=")
        @str << " "
        node.args[1].accept self
      elsif node_obj && !is_alpha(node.name) && node.args.size == 0
        @str << decorate_call(node, node.name)
        in_parenthesis(need_parens, node_obj)
      elsif node_obj && !is_alpha(node.name) && node.args.size == 1
        in_parenthesis(need_parens, node_obj)

        @str << " "
        @str << decorate_call(node, node.name)
        @str << " "

        arg = node.args[0]
        in_parenthesis(need_parens(arg), arg)
      else
        if node_obj
          in_parenthesis(need_parens, node_obj)
          @str << "."
        end
        if node.name.ends_with?('=')
          @str << decorate_call(node, node.name[0..-2])
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
            arg_needs_parens = arg.is_a?(Cast)
            in_parenthesis(arg_needs_parens) { arg.accept self }
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
        end
      end

      block = node.block

      if block
        # Check if this is foo &.bar
        first_block_arg = block.args.first?
        if first_block_arg && block.args.size == 1
          block_body = block.body
          if block_body.is_a?(Call)
            block_obj = block_body.obj
            if block_obj.is_a?(Var) && block_obj.name == first_block_arg.name
              if node.args.empty?
                @str << "("
              else
                @str << ", "
              end
              @str << "&."
              visit_call block_body, ignore_obj: true
              @str << ")"
              return false
            end
          end
        end
      end

      @str << ")" if call_args_need_parens

      if block
        @str << " "
        block.accept self
      end

      false
    end

    private def need_parens(obj)
      case obj
      when Call
        case obj.args.size
        when 0
          !is_alpha(obj.name)
        else
          true
        end
      when Var, NilLiteral, BoolLiteral, CharLiteral, NumberLiteral, StringLiteral,
           StringInterpolation, Path, Generic, InstanceVar, Global
        false
      when ArrayLiteral
        !!obj.of
      when HashLiteral
        !!obj.of
      else
        true
      end
    end

    def in_parenthesis(need_parens)
      if need_parens
        @str << "("
        yield
        @str << ")"
      else
        yield
      end
    end

    def in_parenthesis(need_parens, node)
      in_parenthesis(need_parens) do
        if node.is_a?(Expressions) && node.expressions.size == 1
          node.expressions.first.accept self
        else
          node.accept self
        end
      end
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

    def visit(node : TypeNode)
      node.type.to_s(@str)
      false
    end

    def visit_backtick(exp)
      @str << '`'
      case exp
      when StringLiteral
        @str << exp.value.inspect[1..-2]
      when StringInterpolation
        visit_interpolation exp, &.gsub('`', "\\`")
      end
      @str << '`'
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
      string[0].alpha?
    end

    def visit(node : Assign)
      node.target.accept self
      @str << " = "
      accept_with_maybe_begin_end node.value
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
      @str << keyword(name)
      @str << " "
      node.cond.accept self
      newline
      accept_with_indent(node.body)
      append_indent
      @str << keyword("end")
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
      if node.def.args.size > 0
        @str << "("
        node.def.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")"
      end
      @str << " "
      @str << keyword("do")
      newline
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

      if node.args.size > 0
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
      @str << "abstract " if node.abstract?
      @str << "macro " if node.macro_def?
      @str << keyword("def")
      @str << " "
      if node_receiver = node.receiver
        node_receiver.accept self
        @str << "."
      end
      @str << def_name(node.name)
      if node.args.size > 0 || node.block_arg
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          @str << "*" if node.splat_index == i
          arg.accept self
        end
        if block_arg = node.block_arg
          @str << ", " if node.args.size > 0
          @str << "&"
          block_arg.accept self
        end
        @str << ")"
      end
      if return_type = node.return_type
        @str << " : "
        return_type.accept self
      end
      newline

      unless node.abstract?
        accept_with_indent(node.body)
        append_indent
        @str << keyword("end")
      end
      false
    end

    def visit(node : Macro)
      @str << keyword("macro")
      @str << " "
      @str << node.name.to_s
      if node.args.size > 0 || node.block_arg
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        if block_arg = node.block_arg
          @str << ", " if node.args.size > 0
          @str << "&"
          block_arg.accept self
        end
        @str << ")"
      end
      newline

      inside_macro do
        accept_with_indent node.body
      end

      # newline
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : MacroExpression)
      @str << (node.output ? "{{" : "{% ")
      @str << " " if node.output
      node.exp.accept self
      @str << " " if node.output
      @str << (node.output ? "}}" : " %}")
      false
    end

    def visit(node : MacroIf)
      @str << "{% if "
      node.cond.accept self
      @str << " %}"
      inside_macro do
        node.then.accept self
      end
      unless node.else.nop?
        @str << "{% else %}"
        inside_macro do
          node.else.accept self
        end
      end
      @str << "{% end %}"
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
      @str << " %}"
      inside_macro do
        node.body.accept self
      end
      @str << "{% end %}"
      false
    end

    def visit(node : MacroVar)
      @str << '%'
      @str << node.name
      if exps = node.exps
        @str << '{'
        exps.each_with_index do |exp, i|
          @str << ", " if i > 0
          exp.accept self
        end
        @str << '}'
      end
      false
    end

    def visit(node : MacroLiteral)
      @str << node.value
      false
    end

    def visit(node : External)
      node.fun_def?.try &.accept self
      false
    end

    def visit(node : ExternalVar)
      @str << "$"
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
      if type = node.type?
        @str << " : "
        TypeNode.new(type).accept(self)
      elsif restriction = node.restriction
        @str << " : "
        restriction.accept self
      end
      if default_value = node.default_value
        @str << " = "
        default_value.accept self
      end
      false
    end

    def visit(node : Fun)
      @str << "("
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
      @str << ")"
      false
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
      if @inside_lib && node.name.names.size == 1
        case node.name.names.first
        when "Pointer"
          node.type_vars.first.accept self
          @str << "*"
          return false
        when "StaticArray"
          if node.type_vars.size == 2
            node.type_vars[0].accept self
            @str << "["
            node.type_vars[1].accept self
            @str << "]"
            return false
          end
        end
      end

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

    def visit(node : Union)
      node.types.each_with_index do |ident, i|
        @str << " | " if i > 0
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
      if node.exps.size > 0
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
        accept_with_maybe_begin_end exp
      end
      false
    end

    def visit(node : RegexLiteral)
      @str << "/"
      case exp = node.value
      when StringLiteral
        @str << exp.value
      when StringInterpolation
        visit_interpolation exp, &.gsub('/', "\\/")
      end
      @str << "/"
      @str << "i" if node.options.includes? Regex::Options::IGNORE_CASE
      @str << "m" if node.options.includes? Regex::Options::MULTILINE
      @str << "x" if node.options.includes? Regex::Options::EXTENDED
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

    def visit(node : TypeDeclaration)
      node.var.accept self
      @str << " : "
      node.declared_type.accept self
      false
    end

    def visit(node : UninitializedVar)
      node.var.accept self
      @str << " = uninitialized "
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

      newline
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

    def to_s_binary(node, op)
      left_needs_parens = need_parens(node.left)
      in_parenthesis(left_needs_parens, node.left)

      @str << " "
      @str << op
      @str << " "

      right_needs_parens = need_parens(node.right)
      in_parenthesis(right_needs_parens, node.right)
      false
    end

    def visit(node : Global)
      @str << node.name
    end

    def visit(node : LibDef)
      @str << keyword("lib")
      @str << " "
      @str << node.name
      newline
      @inside_lib = true
      accept_with_indent(node.body)
      @inside_lib = false
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
      if node.args.size > 0
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          if arg_name = arg.name
            @str << arg_name << " : "
          end
          arg.restriction.not_nil!.accept self
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
        newline
        accept_with_indent body
        newline
        append_indent
        @str << keyword("end")
      end
      false
    end

    def visit(node : TypeDef)
      @str << keyword("type")
      @str << " "
      @str << node.name.to_s
      @str << " = "
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
      newline
      @inside_struct_or_union = true
      accept_with_indent node.body
      @inside_struct_or_union = false
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
      newline
      with_indent do
        node.members.each do |member|
          append_indent
          member.accept self
          newline
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
      accept_with_maybe_begin_end node.obj
      @str << " "
      @str << keyword("as")
      @str << " "
      node.to.accept self
      false
    end

    def visit(node : RespondsTo)
      node.obj.accept self
      @str << ".responds_to?(" << node.name << ")"
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
      newline
      node.whens.each do |wh|
        wh.accept self
      end
      if node_else = node.else
        append_indent
        @str << keyword("else")
        newline
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
      newline
      accept_with_indent node.body
      false
    end

    def visit(node : ImplicitObj)
      false
    end

    def visit(node : ExceptionHandler)
      @str << keyword("begin")
      newline

      accept_with_indent node.body

      node.rescues.try &.each do |a_rescue|
        append_indent
        a_rescue.accept self
      end

      if node_else = node.else
        append_indent
        @str << keyword("else")
        newline
        accept_with_indent node_else
      end

      if node_ensure = node.ensure
        append_indent
        @str << keyword("ensure")
        newline
        accept_with_indent node_ensure
      end

      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : Rescue)
      @str << keyword("rescue")
      if name = node.name
        @str << " "
        @str << name
      end
      if (types = node.types) && types.size > 0
        if node.name
          @str << " :"
        end
        @str << " "
        types.each_with_index do |type, i|
          @str << " | " if i > 0
          type.accept self
        end
      end
      newline
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
      @str << "@["
      @str << node.name
      if !node.args.empty? || node.named_args
        @str << "("
        printed_arg = false
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
          printed_arg = true
        end
        if named_args = node.named_args
          @str << ", " if printed_arg
          named_args.each do |named_arg|
            @str << named_arg.name
            @str << ": "
            named_arg.value.accept self
            printed_arg = true
          end
        end
        @str << ")"
      end
      @str << "]"
      false
    end

    def visit(node : MagicConstant)
      @str << node.name
    end

    def visit(node : Asm)
      node.text.inspect(@str)
      @str << " :"
      if output = node.output
        @str << " "
        output.accept self
        @str << " "
      end
      @str << ":"
      if inputs = node.inputs
        @str << " "
        inputs.each_with_index do |input, i|
          @str << ", " if i > 0
          input.accept self
        end
      end
      if clobbers = node.clobbers
        @str << " : "
        clobbers.each_with_index do |clobber, i|
          @str << ", " if i > 0
          clobber.inspect(@str)
        end
      end
      if node.volatile || node.alignstack || node.intel
        @str << " : "
        comma = false
        if node.volatile
          @str << %("volatile")
          comma = true
        end
        if node.alignstack
          @str << ", " if comma
          @str << %("alignstack")
          comma = true
        end
        if node.intel
          @str << ", " if comma
          @str << %("intel")
          comma = true
        end
      end
      false
    end

    def visit(node : AsmOperand)
      node.constraint.inspect(@str)
      @str << '('
      node.exp.accept self
      @str << ')'
      false
    end

    def visit(node : FileNode)
      @str.puts
      @str << "# " << node.filename
      @str.puts
      node.node.accept self
      false
    end

    def newline
      @str << "\n"
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
      newline
    end

    def accept_with_maybe_begin_end(node)
      if node.is_a?(Expressions)
        if node.expressions.size == 1
          @str << "("
          node.expressions.first.accept self
          @str << ")"
        else
          @str << keyword("begin")
          newline
          accept_with_indent(node)
          append_indent
          @str << keyword("end")
        end
      else
        node.accept self
      end
    end

    def inside_macro
      @inside_macro += 1
      yield
      @inside_macro -= 1
    end

    def to_s
      @str.to_s
    end

    def to_s(io)
      @str.to_s(io)
    end
  end
end
