module Crystal::Doc::Highlighter
  extend self

  def highlight(code)
    lexer = Lexer.new(code)
    lexer.comments_enabled = true
    lexer.count_whitespace = true
    lexer.wants_raw = true

    String.build do |io|
      begin
        highlight_normal_state lexer, io
      rescue Crystal::SyntaxException
      end
    end
  end

  private def highlight_normal_state(lexer, io, break_on_rcurly = false)
    last_is_def = false

    while true
      token = lexer.next_token
      case token.type
      when :NEWLINE
        io.puts
      when :SPACE
        io << token.value
      when :COMMENT
        highlight HTML.escape(token.value.to_s), "c", io
      when :NUMBER
        highlight token.raw, "n", io
      when :CHAR
        highlight token.raw, "s", io
      when :SYMBOL
        highlight HTML.escape(token.raw), "n", io
      when :CONST, :"::"
        highlight token, "t", io
      when :DELIMITER_START
        highlight_delimiter_state lexer, token, io
      when :STRING_ARRAY_START, :SYMBOL_ARRAY_START
        highlight_string_array lexer, token, io
      when :EOF
        break
      when :IDENT
        if last_is_def
          last_is_def = false
          highlight token, "m", io
        else
          case token.value
          when :def, :if, :else, :elsif, :end,
               :class, :module, :include, :extend,
               :while, :until, :do, :yield, :return, :unless, :next, :break, :begin,
               :lib, :fun, :type, :struct, :union, :enum, :macro, :out, :require,
               :case, :when, :then, :of, :abstract, :rescue, :ensure, :is_a?,
               :alias, :pointerof, :sizeof, :instance_sizeof, :as, :typeof, :for, :in,
               :undef, :with, :self, :super, :private, :protected, "new"
            highlight token, "k", io
          when :true, :false, :nil
            highlight token, "n", io
          else
            io << token
          end
        end
      when :"+", :"-", :"*", :"/", :"=", :"==", :"<", :"<=", :">", :">=", :"!", :"!=", :"=~", :"!~", :"&", :"|", :"^", :"~", :"**", :">>", :"<<", :"%", :"[]", :"[]?", :"[]=", :"<=>", :"==="
        highlight token, "o", io
      when :"}"
        if break_on_rcurly
          break
        else
          io << token
        end
      else
        io << token
      end

      unless token.type == :SPACE
        last_is_def = token.keyword? :def
      end
    end
  end

  private def highlight_delimiter_state(lexer, token, io)
    start_highlight_class "s", io

    HTML.escape(token.raw, io)

    while true
      token = lexer.next_string_token(token.delimiter_state)
      case token.type
      when :DELIMITER_END
        HTML.escape(token.raw, io)
        end_highlight_class io
        break
      when :INTERPOLATION_START
        end_highlight_class io
        highlight "\#{", "i", io
        end_highlight_class io
        highlight_normal_state lexer, io, break_on_rcurly: true
        start_highlight_class "s", io
        highlight "}", "i", io
      when :EOF
        break
      else
        HTML.escape(token.raw, io)
      end
    end
  end

  private def highlight_string_array(lexer, token, io)
    start_highlight_class "s", io
    HTML.escape(token.raw, io)
    first = true
    while true
      lexer.next_string_array_token
      case token.type
      when :STRING
        io << " " unless first
        HTML.escape(token.raw, io)
        first = false
      when :STRING_ARRAY_END
        HTML.escape(token.raw, io)
        end_highlight_class io
        break
      when :EOF
        raise "Unterminated symbol array literal"
      end
    end
  end

  private def highlight(token, klass, io)
    start_highlight_class klass, io
    io << token
    end_highlight_class io
  end

  private def start_highlight_class(klass, io)
    io << %(<span class=")
    io << klass
    io << %(">)
  end

  private def end_highlight_class(io)
    io << %(</span>)
  end
end
