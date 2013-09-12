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
      @str = ""
      @indent = 0
    end

    def visit_allocate(node)
      @str << 'allocate()'
    end

    def visit_nil_literal(node)
      @str << 'nil'
    end

    def visit_bool_literal(node)
      @str << (node.value ? 'true' : 'false')
    end

    def visit_number_literal(node)
      @str << node.value.to_s
      if node.kind != :i32 && node.kind != :f64
        @str << "_"
        @str << node.kind.to_s
      end
    end

    def visit_char_literal(node)
      @str << "'"
      case node.value.chr
      when ?\t
        @str << '\t'
      when ?\n
        @str << '\n'
      when ?\r
        @str << '\r'
      when ?\0
        @str << '\0'
      else
        @str << node.value.chr
      end
      @str << "'"
    end

    def visit_string_literal(node)
      @str << '"'
      @str << node.value.gsub('"', "\\\"")
      @str << '"'
    end

    def visit_string_interpolation(node)
      @str << '"'
      node.expressions.each do |exp|
        if exp.is_a?(StringLiteral)
          @str << exp.value.gsub('"', "\\\"")
        else
          @str << '#{'
          exp.accept(self)
          @str << '}'
        end
      end
      @str << '"'
      false
    end

    def visit_symbol_literal(node)
      @str << ':'
      @str << node.value
    end

    def visit_range_literal(node)
      node.from.accept self
      if node.exclusive
        @str << '..'
      else
        @str << '...'
      end
      node.to.accept self
      false
    end

    def visit_regexp_literal(node)
      @str << '/'
      @str << node.value
      @str << '/'
    end

    def visit_array_literal(node)
      @str << '['
      node.elements.each_with_index do |exp, i|
        @str << ', ' if i > 0
        exp.accept self
      end
      @str << ']'
      if node.of
        @str << ' of '
        node.of.accept self
      end
      false
    end

    def visit_hash_literal(node)
      @str << '{'
      node.keys.each_with_index do |key, i|
        @str << ', ' if i > 0
        key.accept self
        @str << ' => '
        node.values[i].accept self
      end
      @str << '}'

      if node.of_key
        @str << " of "
        node.of_key.accept self
        @str << " => "
        node.of_value.accept self
      end
      false
    end

    def visit_and(node)
      to_s_binary node, '&&'
    end

    def visit_or(node)
      to_s_binary node, '||'
    end

    def visit_simple_or(node)
      to_s_binary node, 'or'
    end

    def to_s_binary(node, op)
      node.left.accept self
      @str << ' '
      @str << op
      @str << ' '
      node.right.accept self
      false
    end

    def visit_not(node)
      @str << "!("
      node.exp.accept self
      @str << ")"
      false
    end

    def visit_call(node)
      need_parens = node.obj.is_a?(Call) || node.obj.is_a?(Assign)

      @str << "::" if node.global

      if node.obj && node.name == :'[]'

        @str << "(" if need_parens
        node.obj.accept self
        @str << ")" if need_parens

        @str << decorate_call(node, "[")

        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << decorate_call(node, "]")
      elsif node.obj && node.name == :'[]='
        @str << "(" if need_parens
        node.obj.accept self
        @str << ")" if need_parens

        @str << decorate_call(node, "[")

        node.args[0].accept self
        @str << decorate_call(node, "] = ")
        node.args[1].accept self
      elsif node.obj && !is_alpha(node.name) && node.args.length == 0
        if node.name.to_s.end_with? '@'
          @str << decorate_call(node, node.name[0 ... -1].to_s)
        else
          @str << decorate_call(node, node.name.to_s)
        end
        @str << "("
        node.obj.accept self
        @str << ")"
      elsif node.obj && !is_alpha(node.name) && node.args.length == 1
        @str << "(" if need_parens
        node.obj.accept self
        @str << ")" if need_parens

        @str << " "
        @str << decorate_call(node, node.name.to_s)
        @str << " "
        node.args[0].accept self
      else
        if node.obj
          need_parens = node.obj.is_a?(Call) || node.obj.is_a?(Assign)
          @str << "(" if need_parens
          node.obj.accept self
          @str << ")" if need_parens
          @str << "."
        end
        if node.name.to_s.end_with?('=')
          @str << decorate_call(node, node.name.to_s[0 .. -2])
          @str << " = "
          node.args.each_with_index do |arg, i|
            @str << ", " if i > 0
            arg.accept self
          end
        else
          @str << decorate_call(node, node.name.to_s)
          @str << "(" unless node.obj && node.args.empty?
          node.args.each_with_index do |arg, i|
            @str << ", " if i > 0
            arg.accept self
          end
          @str << ")" unless node.obj && node.args.empty?
        end
      end
      if node.block
        @str << " "
        node.block.accept self
      end
      false
    end

    def decorate_call(node, str)
      str
    end

    def decorate_var(node, str)
      str
    end

    def visit_require(node)
      @str << "require \""
      @str << node.string
      @str << "\""
      if node.cond
        @str << " if "
        node.cond.accept self
      end
      false
    end

    def is_alpha(string)
      c = string.to_s[0].downcase
      'a' <= c && c <= 'z'
    end

    def visit_block(node)
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

    def visit_fun_literal(node)
      @str << "->"
      if node.def.args.length > 0
        @str << "("
        node.def.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")"
      end
      @str << " do\n"
      accept_with_indent(node.def.body)
      append_indent
      @str << "end"
      false
    end

    def visit_fun_pointer(node)
      @str << "->"
      if node.obj
        node.obj.accept self
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
      false
    end

    def visit_def(node)
      @str << "def "
      if node.receiver
        node.receiver.accept self
        @str << "."
      end
      @str << node.name.to_s
      if node.args.length > 0 || node.block_arg
        @str << "("
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
          i += 1
        end
        if node.block_arg
          @str << ", " if node.args.length > 0
          @str << "&"
          node.block_arg.accept self
        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
      false
    end

    def visit_macro(node)
      @str << "macro "
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
          i += 1

        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
      false
    end

    def visit_frozen_def(node)
      visit_def(node)
      false
    end

    def visit_external(node)
      visit_def(node)
      false
    end

    def visit_var(node)
      @str << "out " if node.out
      if node.name
        @str << decorate_var(node, node.name)
      else
        @str << decorate_var(node, '?')
      end
    end

    def visit_global(node)
      @str << node.name
    end

    def visit_arg(node)
      if node.name
        @str << node.name
      else
        @str << '?'
      end
      if node.default_value
        @str << ' = '
        node.default_value.accept self
      end
      if node.type_restriction
        @str << ' : '
        if node.type_restriction.is_a?(ASTNode)
          node.type_restriction.accept self
        else
          @str << node.type_restriction.to_s
        end
      end
      false
    end

    def visit_block_arg(node)
      @str << node.name
      if node.type_spec
        @str << " : "
        node.type_spec.accept self
      end
      false
    end

    def visit_fun_type_spec(node)
      if node.inputs
        node.inputs.each_with_index do |input, i|
          @str << ", " if i > 0
          input.accept self
        end
      end
      @str << " -> "
      node.output.accept self if node.output
    end

    def visit_ident(node)
      node.names.each_with_index do |name, i|
        @str << '::' if i > 0 || node.global
        @str << name
      end
    end

    def visit_ident_union(node)
      node.idents.each_with_index do |ident, i|
        @str << " | " if  i > 0
        ident.accept self
      end
      false
    end

    def visit_self_type(node)
      @str << "self"
    end

    def visit_instance_var(node)
      @str << "out " if node.out
      @str << decorate_var(node, node.name)
    end

    def visit_class_var(node)
      @str << "out " if node.out
      @str << decorate_var(node, node.name)
    end

    def visit_nop(node)
    end

    def visit_expressions(node)
      node.expressions.each do |exp|
        next if exp.nop?

        append_indent
        exp.accept self
        @str << "\n"
      end
      false
    end

    def visit_if(node)
      @str << "if "
      node.cond.accept self
      @str << "\n"
      accept_with_indent(node.then)
      unless node.else.nop?
        append_indent
        @str << "else\n"
        accept_with_indent(node.else)
      end
      append_indent
      @str << "end"
      false
    end

    def visit_unless(node)
      @str << "if "
      node.cond.accept self
      @str << "\n"
      accept_with_indent(node.then)
      unless node.else.nop?
        append_indent
        @str << "else\n"
        accept_with_indent(node.else)
      end
      append_indent
      @str << "end"
      false
    end

    def visit_class_def(node)
      @str << "abstract " if node.abstract
      @str << "class "
      node.name.accept self
      if node.type_vars
        @str << "("
        node.type_vars.each_with_index do |type_var, i|
          @str << ", " if i > 0
          @str << type_var.to_s
        end
        @str << ")"
      end
      if node.superclass
        @str << " < "
        node.superclass.accept self
      end
      @str << "\n"
      accept_with_indent(node.body)
      @str << "end"
      false
    end

    def visit_module_def(node)
      @str << "module "
      node.name.accept self
      if node.type_vars
        @str << "("
        node.type_vars.each_with_index do |type_var, i|
          @str << ", " if i > 0
          @str << type_var.to_s
        end
        @str << ")"
      end
      @str << "\n"
      accept_with_indent(node.body)
      @str << "end"
      false
    end

    def visit_include(node)
      @str << "include "
      node.name.accept self
      false
    end

    def visit_assign(node)
      node.target.accept self
      @str << " = "
      if node.value.is_a?(Expressions)
        @str << "begin\n"
        accept_with_indent(node.value)
        append_indent
        @str << "end"
      else
        node.value.accept self
      end
      false
    end

    def visit_multi_assign(node)
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

    def visit_while(node)
      if node.run_once
        if node.body.is_a?(Expressions)
          @str << "begin\n"
          accept_with_indent(node.body)
          append_indent
          @str << "end while "
        else
          node.body.accept self
          @str << " while "
        end
        node.cond.accept self
      else
        @str << "while "
        node.cond.accept self
        @str << "\n"
        accept_with_indent(node.body)
        append_indent
        @str << "end"
      end
      false
    end

    def visit_lib_def(node)
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
      @str << 'end'
      false
    end

    def visit_fun_def(node)
      @str << 'fun '
      if node.name == node.real_name
        @str << node.name
      else
        @str << node.name
        @str << ' = '
        @str << node.real_name
      end
      if node.args.length > 0
        @str << '('
        node.args.each_with_index do |arg, i|
          @str << ', ' if i > 0
          arg.accept self
        end
        if node.varargs
          @str << ', ...'
        end
        @str << ')'
      end
      if node.return_type
        @str << ' : '
        node.return_type.accept self
      end
      if node.body
        @str << "\n"
        accept_with_indent node.body
        @str << "\n"
        append_indent
        @str << "end"
      end
      false
    end

    def visit_type_def(node)
      @str << 'type '
      @str << node.name.to_s
      @str << ' : '
      node.type.accept self
      false
    end

    def visit_struct_def(node)
      @str << 'struct '
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
      @str << 'end'
      false
    end

    def visit_union_def(node)
      @str << 'union '
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
      @str << 'end'
      false
    end

    def visit_enum_def(node)
      @str << 'enum '
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
      @str << 'end'
      false
    end

    def visit_external_var(node)
      @str << "$"
      @str << node.name.to_s
      @str << " : "
      node.type_spec.accept self
      false
    end

    def visit_pointer_of(node)
      node.var.accept(self)
      @str << '.ptr'
      false
    end

    def visit_is_a(node)
      node.obj.accept self
      @str << ".is_a?("
      node.const.accept self
      @str << ")"
      false
    end

    def visit_responds_to(node)
      node.obj.accept self
      @str << ".responds_to?("
      node.name.accept self
      @str << ")"
      false
    end

    def visit_case(node)
      @str << 'case '
      node.cond.accept self
      @str << "\n"
      node.whens.each do |wh|
        wh.accept self
      end
      if node.else
        @str << "else\n"
        accept_with_indent node.else
      end
      @str << 'end'
      false
    end

    def visit_when(node)
      @str << 'when '
      node.conds.each_with_index do |cond, i|
        @str << ', ' if i > 0
        cond.accept self
      end
      @str << "\n"
      accept_with_indent node.body
      false
    end

    def visit_new_generic_class(node)
      node.name.accept self
      @str << "("
      node.type_vars.each_with_index do |var, i|
        @str << ', ' if i > 0
        var.accept self
      end
      @str << ")"
      false
    end

    ['return', 'next', 'break'].each do |keyword|
      class_eval <<-EVAL, __FILE__, __LINE__ + 1
        def visit_#{keyword}(node)
          @str << '#{keyword}'
          if node.exps.length > 0
            @str << ' '
            node.exps.each_with_index do |exp, i|
              @str << ", " if i > 0
              exp.accept self
            end
          end
          false
        end
      EVAL
    end

    def visit_yield(node)
      if node.scope
        node.scope.accept self
        @str << '.'
      end
      @str << 'yield'
      if node.exps.length > 0
        @str << ' '
        node.exps.each_with_index do |exp, i|
          @str << ", " if i > 0
          exp.accept self
        end
      end
      false
    end

    def visit_declare_var(node)
      @str << node.name
      @str << " :: "
      node.declared_type.accept self
      false
    end

    def visit_exception_handler(node)
      @str << "begin\n"

      if node.body
        accept_with_indent node.body
      end

      if node.rescues && node.rescues.length > 0
        node.rescues.each do |a_rescue|
          append_indent
          a_rescue.accept self
        end
      end

      if node.else
        append_indent
        @str << "else\n"
        accept_with_indent node.else
      end

      if node.ensure
        append_indent
        @str << "ensure\n"
        accept_with_indent node.ensure
      end

      append_indent
      @str << "end"
      false
    end

    def visit_rescue(node)
      @str << "rescue "
      if node.name
        @str << node.name
      end
      if node.name && node.types && node.types.length > 0
        @str << " : "
      end
      if node.types && node.types.length > 0
        node.types.each_with_index do |type, i|
          @str << " | " if i > 0
          type.accept self
        end
      end
      @str << "\n"
      if node.body
        accept_with_indent node.body
      end
      false
    end

    def visit_type_merge(node)
      @str << "<type_merge>("
      node.expressions.each_with_index do |exp, i|
        @str << ', ' if i > 0
        exp.accept self
      end
      @str << ")"
      false
    end

    def with_indent
      @indent += 1
      yield
      @indent -= 1
    end

    def accept_with_indent(node)
      return unless node
      doesnt_need_indent = node.is_a?(Expressions) || node.nop?
      with_indent do
        append_indent unless doesnt_need_indent
        node.accept self
      end
      @str << "\n" unless doesnt_need_indent
    end

    def append_indent
      @str << ('  ' * @indent)
    end

    def to_s
      @str.strip
    end
  end
end
