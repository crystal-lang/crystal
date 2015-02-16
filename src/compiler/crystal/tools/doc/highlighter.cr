module Crystal::Doc::Highlighter
  extend self

  def highlight(code)
    lexer = Lexer.new(code)
    lexer.comments_enabled = true
    lexer.count_whitespace = true

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
        highlight token, "c", io
      when :NUMBER
        highlight token, "n", io
      when :CHAR
        highlight token.value.inspect, "s", io
      when :SYMBOL
        sym = token.value.to_s
        if Symbol.needs_quotes?(sym)
          highlight %(:#{sym.inspect}), "n", io
        else
          highlight ":#{sym}", "n", io
        end
      when :CONST, :"::"
        highlight token, "t", io
      when :DELIMITER_START
        highlight_delimiter_state lexer, token, io
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
               :alias, :pointerof, :sizeof, :instance_sizeof, :ifdef, :as, :typeof, :for, :in,
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
    start_highlight_klass "s", io

    delimiter_end = token.delimiter_state.end
    case delimiter_end
    when '/' then io << '/'
    when '"' then io << '"'
    when '`' then io << '`'
    when ')' then io << "%("
    end

    while true
      token = lexer.next_string_token(token.delimiter_state)
      case token.type
      when :DELIMITER_END
        io << delimiter_end
        end_highlight_klass io
        break
      when :INTERPOLATION_START
        end_highlight_klass io
        highlight "\#{", "i", io
        end_highlight_klass io
        highlight_normal_state lexer, io, break_on_rcurly: true
        start_highlight_klass "s", io
        highlight "}", "i", io
      when :EOF
        break
      else
        io << token
      end
    end
  end

  private def highlight(token, klass, io)
    start_highlight_klass klass, io
    io << token
    end_highlight_klass io
  end

  private def start_highlight_klass(klass, io)
    io << %(<span class=")
    io << klass
    io << %(">)
  end

  private def end_highlight_klass(io)
    io << %(</span>)
  end
end
