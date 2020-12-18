module Crystal::Doc::Highlighter
  extend self

  def highlight(code)
    lexer = Lexer.new(code)
    lexer.comments_enabled = true
    lexer.count_whitespace = true
    lexer.wants_raw = true

    begin
      String.build { |io| highlight_normal_state lexer, io }
    rescue
      code
    end
  end

  private def highlight_normal_state(lexer, io, break_on_rcurly = false)
    last_is_def = false
    heredoc_stack = [] of Token

    while true
      token = lexer.next_token
      case token.type
      when :NEWLINE
        io.puts
        heredoc_stack.each_with_index do |token, i|
          highlight_delimiter_state lexer, token, io, heredoc: true
          unless i == heredoc_stack.size - 1
            # Next token to heredoc's end is either NEWLINE or EOF.
            if lexer.next_token.type == :EOF
              raise "Unterminated heredoc"
            end
            io.puts
          end
        end
        heredoc_stack.clear
      when :SPACE
        io << token.value
      when :COMMENT
        highlight HTML.escape(token.value.to_s), "c", io
      when :NUMBER
        highlight token.raw, "n", io
      when :CHAR
        highlight HTML.escape(token.raw), "s", io
      when :SYMBOL
        highlight HTML.escape(token.raw), "n", io
      when :CONST, :"::"
        highlight token, "t", io
      when :DELIMITER_START
        if token.delimiter_state.kind == :heredoc
          highlight HTML.escape(token.raw), "s", io
          heredoc_stack << token.dup
        else
          highlight_delimiter_state lexer, token, io
        end
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
               :case, :when, :select, :then, :of, :abstract, :rescue, :ensure, :is_a?,
               :alias, :pointerof, :sizeof, :instance_sizeof, :offsetof, :as, :as?, :typeof, :for, :in,
               :undef, :with, :self, :super, :private, :asm, :nil?, :protected, :uninitialized, "new",
               :annotation, :verbatim
            highlight token, "k", io
          when :true, :false, :nil
            highlight token, "n", io
          else
            io << token
          end
        end
      when :+, :-, :*, :&+, :&-, :&*, :/, ://,
           :"=", :==, :<, :<=, :>, :>=, :!, :!=, :=~, :!~,
           :&, :|, :^, :~, :**, :>>, :<<, :%,
           :[], :[]?, :[]=, :<=>, :===
        highlight HTML.escape(token.to_s), "o", io
      when :"}"
        if break_on_rcurly
          break
        else
          io << token
        end
      when :UNDERSCORE
        io << '_'
      else
        io << token
      end

      unless token.type == :SPACE
        last_is_def = token.keyword? :def
      end
    end
  end

  private def highlight_delimiter_state(lexer, token, io, heredoc = false)
    start_highlight_class "s", io

    HTML.escape(token.raw, io) unless heredoc

    while true
      token = lexer.next_string_token(token.delimiter_state)
      case token.type
      when :DELIMITER_END
        HTML.escape(token.raw, io)
        break
      when :INTERPOLATION_START
        end_highlight_class io
        highlight "\#{", "i", io
        highlight_normal_state lexer, io, break_on_rcurly: true
        highlight "}", "i", io
        start_highlight_class "s", io
      else
        HTML.escape(token.raw, io)
      end
    end

    end_highlight_class io
  end

  private def highlight_string_array(lexer, token, io)
    start_highlight_class "s", io
    HTML.escape(token.raw, io)
    while true
      consume_space_or_newline(lexer, io)
      token = lexer.next_string_array_token
      case token.type
      when :STRING
        HTML.escape(token.raw, io)
      when :STRING_ARRAY_END
        HTML.escape(token.raw, io)
        end_highlight_class io
        break
      when :EOF
        if token.delimiter_state.kind == :string_array
          raise "Unterminated string array literal"
        else # == :symbol_array
          raise "Unterminated symbol array literal"
        end
      else
        raise "Bug: shouldn't happen"
      end
    end
  end

  def consume_space_or_newline(lexer, io)
    while true
      char = lexer.current_char
      case char
      when '\n'
        lexer.next_char
        lexer.incr_line_number 1
        io.puts
      when .ascii_whitespace?
        lexer.next_char
        io << char
      else
        break
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
