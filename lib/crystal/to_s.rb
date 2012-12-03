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

    def visit_alloc(node)
      @str << 'alloc()'
    end

    def visit_nil_literal(node)
      @str << 'nil'
    end

    def visit_bool_literal(node)
      @str << (node.value ? 'true' : 'false')
    end

    def visit_int_literal(node)
      @str << node.value.to_s
    end

    def visit_float_literal(node)
      @str << node.value.to_s
    end

    def visit_char_literal(node)
      @str << "'"
      @str << node.value.chr
      @str << "'"
    end

    def visit_string_literal(node)
      @str << '"'
      @str << node.value.gsub('"', "\\\"")
      @str << '"'
    end

    def visit_symbol_literal(node)
      @str << ':'
      @str << node.value
    end

    def visit_array_literal(node)
      @str << '['
      node.elements.each_with_index do |exp, i|
        @str << ', ' if i > 0
        exp.accept self
      end
      @str << ']'
      false
    end

    def visit_call(node)
      if node.obj && node.name == :'[]'
        node.obj.accept self
        @str << "["
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << "]"
      elsif node.obj && node.name == :'[]='
        node.obj.accept self
        @str << "["
        node.args[0].accept self
        @str << "] = "
        node.args[1].accept self
      elsif node.obj && !is_alpha(node.name) && node.args.length == 0
        if node.name.to_s.end_with? '@'
          @str << node.name[0 ... -1].to_s
        else
          @str << node.name.to_s
        end
        node.obj.accept self
      elsif node.obj && !is_alpha(node.name) && node.args.length == 1
        node.obj.accept self
        @str << " "
        @str << node.name.to_s
        @str << " "
        node.args[0].accept self
      else
        if node.obj
          node.obj.accept self
          @str << "."
        end
        @str << node.name.to_s
        @str << "(" unless node.obj && node.args.empty?
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << ")" unless node.obj && node.args.empty?
      end
      if node.block
        @str << " "
        node.block.accept self
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

    def visit_def(node)
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
      if node.name
        @str << node.name
      else
        @str << '?'
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
      false
    end

    def visit_ident(node)
      node.names.each_with_index do |name, i|
        @str << '::' if i > 0 || node.global
        @str << name
      end
    end

    def visit_instance_var(node)
      @str << node.name
    end

    def visit_expressions(node)
      node.expressions.each do |exp|
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
      if node.else
        append_indent
        @str << "else\n"
        accept_with_indent(node.else)
      end
      append_indent
      @str << "end"
      false
    end

    def visit_class_def(node)
      @str << "class "
      @str << node.name
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
      @str << node.name
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
      node.value.accept self
      false
    end

    def visit_while(node)
      @str << "while "
      node.cond.accept self
      @str << "\n"
      accept_with_indent(node.body)
      append_indent
      @str << "end"
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
      @str << node.name
      if node.args.length > 0
        @str << '('
        node.args.each_with_index do |arg, i|
          @str << ', ' if i > 0
          arg.accept self
        end
        @str << ')'
      end
      if node.return_type
        @str << ' : '
        @str << 'ptr ' if node.ptr
        node.return_type.accept self
      end
      false
    end

    def visit_fun_def_arg(node)
      @str << node.name
      @str << ' : '
      @str << 'ptr ' if node.options[:ptr]
      node.type.accept self
      false
    end

    def visit_type_def(node)
      @str << 'type '
      @str << node.name
      @str << ' : '
      @str << 'ptr ' if node.ptr
      node.type.accept self
      false
    end

    def visit_struct_def(node)
      @str << 'struct '
      @str << node.name
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

    def visit_pointer_of(node)
      node.var.accept(self)
      @str << '.ptr'
      false
    end

    ['return', 'next', 'break', 'yield'].each do |keyword|
      class_eval %Q(
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
      )
    end

    def with_indent
      @indent += 1
      yield
      @indent -= 1
    end

    def accept_with_indent(node)
      return unless node
      is_expressions = node.is_a?(Expressions)
      with_indent do
        append_indent unless is_expressions
        node.accept self
      end
      @str << "\n" unless is_expressions
    end

    def append_indent
      @str << ('  ' * @indent)
    end

    def to_s
      @str.strip
    end
  end
end
