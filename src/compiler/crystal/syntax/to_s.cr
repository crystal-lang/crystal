require "./ast"
require "./visitor"

module Crystal
  class ASTNode
    def inspect(io)
      to_s(io)
    end

    def to_s(io, emit_loc_pragma = false, emit_doc = false)
      visitor = ToSVisitor.new(io, emit_loc_pragma: emit_loc_pragma, emit_doc: emit_doc)
      self.accept visitor
    end
  end

  class ToSVisitor < Visitor
    @str : IO

    def initialize(@str = IO::Memory.new, @emit_loc_pragma = false, @emit_doc = false)
      @indent = 0
      @inside_macro = 0
      @inside_lib = false
    end

    def visit_any(node)
      if @emit_doc && (doc = node.doc) && !doc.empty?
        doc.each_line(chomp: false) do |line|
          append_indent
          @str << "# "
          @str << line
        end
        @str.puts
      end

      if @emit_loc_pragma && (loc = node.location) && loc.filename.is_a?(String)
        @str << "#<loc:"
        loc.filename.inspect(@str)
        @str << ","
        @str << loc.line_number
        @str << ","
        @str << loc.column_number
        @str << ">"
      end

      true
    end

    def visit(node : Nop)
    end

    def visit(node : BoolLiteral)
      @str << decorate_singleton(node, (node.value ? "true" : "false"))
    end

    def visit(node : NumberLiteral)
      @str << node.value

      if needs_suffix?(node)
        @str << "_"
        @str << node.kind.to_s
      end
    end

    def needs_suffix?(node : NumberLiteral)
      case node.kind
      when :i32
        return false
      when :f64
        # If there's no '.' nor 'e', for example in `1_f64`,
        # we need to include it (#3315)
        node.value.each_char do |char|
          case char
          when '.', 'e'
            return false
          end
        end
      end

      true
    end

    def visit(node : CharLiteral)
      node.value.inspect(@str)
    end

    def visit(node : SymbolLiteral)
      visit_symbol_literal_value node.value
    end

    def visit_symbol_literal_value(value : String)
      @str << ':'
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
          @str << yield exp.value
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

      space = false
      @str << "{"

      node.entries.each_with_index do |entry, i|
        @str << ", " if i > 0

        space = i == 0 && entry.key.is_a?(TupleLiteral) || entry.key.is_a?(NamedTupleLiteral) || entry.key.is_a?(HashLiteral)
        @str << " " if space

        entry.key.accept self
        @str << " => "
        entry.value.accept self
      end

      @str << " " if space
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

    def visit(node : NamedTupleLiteral)
      @str << "{"
      node.entries.each_with_index do |entry, i|
        @str << ", " if i > 0
        visit_named_arg_name(entry.key)
        @str << ": "
        entry.value.accept self
      end
      @str << "}"
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
          @str << "*" if node.splat_index == i
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
          @str << "*" if node.splat_index == i
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

      @str << "::" if node.global?

      if node_obj && (node.name == "[]" || node.name == "[]?")
        in_parenthesis(need_parens, node_obj)

        @str << decorate_call(node, "[")
        visit_args(node)
        if node.name == "[]"
          @str << decorate_call(node, "]")
        else
          @str << decorate_call(node, "]?")
        end
      elsif node_obj && node.name == "[]="
        in_parenthesis(need_parens, node_obj)

        @str << decorate_call(node, "[")
        visit_args(node, excluse_last: true)
        @str << decorate_call(node, "]")
        @str << " "
        @str << decorate_call(node, "=")
        @str << " "
        node.args.last.accept self
      elsif node_obj && !letter_or_underscore?(node.name) && node.args.size == 0
        @str << decorate_call(node, node.name)
        in_parenthesis(need_parens, node_obj)
      elsif node_obj && !letter_or_underscore?(node.name) && node.args.size == 1
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
        if node.name.ends_with?('=') && node.name[0].ascii_letter?
          @str << decorate_call(node, node.name.rchop)
          @str << " = "
          node.args.each_with_index do |arg, i|
            @str << ", " if i > 0
            arg.accept self
          end
        else
          @str << decorate_call(node, node.name)

          call_args_need_parens = node.has_parentheses? || !node.args.empty? || node.block_arg || node.named_args

          @str << "(" if call_args_need_parens
          visit_args(node)
        end
      end

      block = node.block

      if block
        # Check if this is foo &.bar
        first_block_arg = block.args.first?
        if first_block_arg && block.args.size == 1 && block.args.first.name.starts_with?("__arg")
          block_body = block.body
          if block_body.is_a?(Call)
            block_obj = block_body.obj
            if block_obj.is_a?(Var) && block_obj.name == first_block_arg.name
              if node.args.empty?
                unless call_args_need_parens
                  @str << "("
                  call_args_need_parens = true
                end
              else
                @str << ", "
              end
              @str << "&."
              visit_call block_body, ignore_obj: true
              block = nil
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

    private def visit_args(node, excluse_last = false)
      printed_arg = false
      node.args.each_with_index do |arg, i|
        break if excluse_last && i == node.args.size - 1

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
    end

    private def need_parens(obj)
      case obj
      when Call
        case obj.args.size
        when 0
          !letter_or_underscore?(obj.name)
        else
          case obj.name
          when "[]", "[]?", "<", "<=", ">", ">="
            false
          else
            true
          end
        end
      when Var, NilLiteral, BoolLiteral, CharLiteral, NumberLiteral, StringLiteral,
           StringInterpolation, Path, Generic, InstanceVar, ClassVar, Global
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
      visit_named_arg_name(node.name)
      @str << ": "
      node.value.accept self
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

    def letter?(string)
      string[0].ascii_letter?
    end

    def letter_or_underscore?(string)
      string[0].ascii_letter? || string[0] == '_'
    end

    def visit(node : Assign)
      node.target.accept self
      @str << " = "
      accept_with_maybe_begin_end node.value
      false
    end

    def visit(node : OpAssign)
      node.target.accept self
      @str << " " << node.op << "=" << " "
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

    def visit(node : ProcLiteral)
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

    def visit(node : ProcPointer)
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
      @str << keyword("def")
      @str << " "
      if node_receiver = node.receiver
        node_receiver.accept self
        @str << "."
      end
      @str << def_name(node.name)
      if node.args.size > 0 || node.block_arg || node.double_splat
        @str << "("
        printed_arg = false
        node.args.each_with_index do |arg, i|
          @str << ", " if printed_arg
          @str << "*" if node.splat_index == i
          arg.accept self
          printed_arg = true
        end
        if double_splat = node.double_splat
          @str << ", " if printed_arg
          @str << "**"
          double_splat.accept self
        end
        if block_arg = node.block_arg
          @str << ", " if printed_arg
          @str << "&"
          block_arg.accept self
          printed_arg = true
        end
        @str << ")"
      end
      if return_type = node.return_type
        @str << " : "
        return_type.accept self
      end

      if free_vars = node.free_vars
        @str << " forall "
        free_vars.join(", ", @str)
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
      if node.args.size > 0 || node.block_arg || node.double_splat
        @str << "("
        printed_arg = false
        node.args.each_with_index do |arg, i|
          @str << ", " if printed_arg
          @str << "*" if i == node.splat_index
          arg.accept self
          printed_arg = true
        end
        if double_splat = node.double_splat
          @str << ", " if printed_arg
          @str << "**"
          double_splat.accept self
          printed_arg = true
        end
        if block_arg = node.block_arg
          @str << ", " if printed_arg
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
      @str << (node.output? ? "{{" : "{% ")
      @str << " " if node.output?
      node.exp.accept self
      @str << " " if node.output?
      @str << (node.output? ? "}}" : " %}")
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
      # These two can only come from an escaped sequence like \{ or \{%
      if node.value == "{" || node.value.starts_with?("{%")
        @str << "\\"
      end
      @str << node.value
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
      if node.external_name != node.name
        visit_named_arg_name(node.external_name)
        @str << " "
      end
      if node.name
        @str << decorate_arg(node, node.name)
      else
        @str << "?"
      end
      if restriction = node.restriction
        @str << " : "
        restriction.accept self
      end
      if default_value = node.default_value
        @str << " = "
        default_value.accept self
      end
      false
    end

    def visit(node : ProcNotation)
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
        @str << "::" if i > 0 || node.global?
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

      printed_arg = false

      @str << "("
      node.type_vars.each_with_index do |var, i|
        @str << ", " if i > 0
        var.accept self
        printed_arg = true
      end

      if named_args = node.named_args
        named_args.each do |named_arg|
          @str << ", " if printed_arg
          visit_named_arg_name(named_arg.name)
          @str << ": "
          named_arg.value.accept self
          printed_arg = true
        end
      end

      @str << ")"
      false
    end

    def visit_named_arg_name(name)
      if Symbol.needs_quotes?(name)
        name.inspect(@str)
      else
        @str << name
      end
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

    def visit(node : DoubleSplat)
      @str << "**"
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
        @str << exp.value.gsub('/', "\\/")
      when StringInterpolation
        visit_interpolation exp, &.gsub('/', "\\/")
      end
      @str << "/"
      @str << "i" if node.options.includes? Regex::Options::IGNORE_CASE
      @str << "m" if node.options.includes? Regex::Options::MULTILINE
      @str << "x" if node.options.includes? Regex::Options::EXTENDED
      false
    end

    def visit(node : TupleLiteral)
      @str << "{"

      first = node.elements.first?
      space = first.is_a?(TupleLiteral) || first.is_a?(NamedTupleLiteral) || first.is_a?(HashLiteral)
      @str << " " if space
      node.elements.each_with_index do |exp, i|
        @str << ", " if i > 0
        exp.accept self
      end
      @str << " " if space
      @str << "}"
      false
    end

    def visit(node : TypeDeclaration)
      node.var.accept self
      @str << " : "
      node.declared_type.accept self
      if value = node.value
        @str << " = "
        value.accept self
      end
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
          @str << "*" if i == node.splat_index
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
      need_parens = need_parens(node.exp)
      in_parenthesis(need_parens, node.exp)
      false
    end

    def visit(node : VisibilityModifier)
      @str << node.modifier.to_s.downcase
      @str << ' '
      node.exp.accept self
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
        if node.varargs?
          @str << ", ..."
        end
        @str << ")"
      elsif node.varargs?
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

    def visit(node : CStructOrUnionDef)
      @str << keyword(node.union? ? "union" : "struct")
      @str << " "
      @str << node.name.to_s
      newline
      accept_with_indent node.body
      append_indent
      @str << keyword("end")
      false
    end

    def visit(node : EnumDef)
      @str << keyword("enum")
      @str << " "
      @str << node.name.to_s
      if base_type = node.base_type
        @str << " : "
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
      need_parens = need_parens(node.from)
      in_parenthesis(need_parens, node.from)

      if node.exclusive?
        @str << "..."
      else
        @str << ".."
      end

      need_parens = need_parens(node.to)
      in_parenthesis(need_parens, node.to)

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
      if node.nil_check?
        @str << ".nil?"
      else
        @str << ".is_a?("
        node.const.accept self
        @str << ")"
      end
      false
    end

    def visit(node : Cast)
      visit_cast node, "as"
    end

    def visit(node : NilableCast)
      visit_cast node, "as?"
    end

    def visit_cast(node, keyword)
      need_parens = need_parens(node.obj)
      in_parenthesis(need_parens, node.obj)
      @str << "."
      @str << keyword(keyword)
      @str << "("
      node.to.accept self
      @str << ")"
      false
    end

    def visit(node : RespondsTo)
      node.obj.accept self
      @str << ".responds_to?("
      visit_symbol_literal_value node.name
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

    def visit(node : Select)
      @str << keyword("select")
      newline
      node.whens.each do |a_when|
        @str << "when "
        a_when.condition.accept self
        newline
        accept_with_indent a_when.body
      end
      if a_else = node.else
        @str << "else"
        newline
        accept_with_indent a_else
      end
      @str << keyword("end")
      newline
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
          named_args.each do |named_arg|
            @str << ", " if printed_arg
            visit_named_arg_name(named_arg.name)
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
      if node.volatile? || node.alignstack? || node.intel?
        @str << " : "
        comma = false
        if node.volatile?
          @str << %("volatile")
          comma = true
        end
        if node.alignstack?
          @str << ", " if comma
          @str << %("alignstack")
          comma = true
        end
        if node.intel?
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
      case node
      when Expressions
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
      when If, Unless, While, Until
        @str << keyword("begin")
        newline
        accept_with_indent(node)
        append_indent
        @str << keyword("end")
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
