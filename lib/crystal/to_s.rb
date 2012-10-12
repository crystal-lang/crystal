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

    def visit_any(node)
      append_indent unless node.is_a?(Expressions)
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
      @str << node.value
      @str << '"'
    end

    def visit_array_literal(node)
      @str << '['
      node.expressions.each_with_index do |exp, i|
        @str << ', ' if i > 0
        exp.accept self
      end
      @str << ']'
      false
    end

    def visit_call(node)
      if node.obj && node.name == :'[ ]'
        node.obj.accept self
        @str << "["
        node.args.each_with_index do |arg, i|
          @str << ", " if i > 0
          arg.accept self
        end
        @str << "]"
      elsif node.obj && node.name.is_a?(Symbol) && node.args.length == 0
        if node.name.to_s.end_with? '@'
          @str << node.name[0 ... -1].to_s
        else
          @str << node.name.to_s
        end
        node.obj.accept self
      elsif node.obj && node.name.is_a?(Symbol) && node.args.length == 1
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
      with_indent { node.body.accept self } if node.body

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
      with_indent { node.body.accept self } if node.body
      @str << "\n"
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

    def visit_const(node)
      @str << node.name
    end

    def visit_instance_var(node)
      @str << node.name
    end

    def visit_expressions(node)
      length = node.expressions.length
      node.expressions.each_with_index do |exp, i|
        exp.accept self
        @str << "\n" unless i == length - 1
      end
      false
    end

    def visit_if(node)
      @str << "if "
      node.cond.accept self
      @str << "\n"
      with_indent { node.then.accept self }
      @str << "\n"
      if node.else
        append_indent
        @str << "else\n"
        with_indent { node.else.accept self }
        @str << "\n"
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
        @str << node.superclass
      end
      @str << "\n"
      with_indent { node.body.accept self }
      @str << "end"
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
      with_indent { node.body.accept self }
      append_indent
      @str << "end"
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

    def append_indent
      @str << ('  ' * @indent)
    end

    def to_s
      @str.strip
    end
  end
end
