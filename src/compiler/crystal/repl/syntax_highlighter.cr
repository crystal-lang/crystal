require "./repl"
require "colorize"

module Crystal::Repl::SyntaxHighlighter
  extend self

  COMMENT_COLOR        = :dark_gray
  NUMBER_COLOR         = :magenta
  CHAR_COLOR           = :light_yellow
  SYMBOL_COLOR         = :magenta
  STRING_COLOR         = :light_yellow
  INTERPOLATION_COLOR  = :light_yellow
  CONST_COLOR          = :cyan
  OPERATOR_COLOR       = :light_red
  IDENT_COLOR          = :light_green
  KEYWORD_COLOR        = :light_red
  TRUE_FALSE_NIL_COLOR = :magenta
  SELF_COLOR           = :blue

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
        highlight token.value.to_s, COMMENT_COLOR, io
      when :NUMBER
        highlight token.raw, NUMBER_COLOR, io
      when :CHAR
        highlight token.raw, CHAR_COLOR, io
      when :SYMBOL
        highlight token.raw, SYMBOL_COLOR, io
      when :CONST, :"::"
        highlight token, CONST_COLOR, io
      when :DELIMITER_START
        if token.delimiter_state.kind == :heredoc
          highlight token.raw, STRING_COLOR, io
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
          highlight token, IDENT_COLOR, io
        else
          case token.value
          when :def, :if, :else, :elsif, :end,
               :class, :module, :include, :extend,
               :while, :until, :do, :yield, :return, :unless, :next, :break, :begin,
               :lib, :fun, :type, :struct, :union, :enum, :macro, :out, :require,
               :case, :when, :select, :then, :of, :abstract, :rescue, :ensure, :is_a?,
               :alias, :pointerof, :sizeof, :instance_sizeof, :offsetof, :as, :as?, :typeof, :for, :in,
               :with, :super, :private, :asm, :nil?, :protected, :uninitialized, "new",
               :annotation, :verbatim, "raise", "loop"
            highlight token, KEYWORD_COLOR, io
          when :true, :false, :nil
            highlight token, TRUE_FALSE_NIL_COLOR, io
          when :self
            highlight token, SELF_COLOR, io
          else
            io << token
          end
        end
      when :+, :-, :*, :&+, :&-, :&*, :/, ://,
           :"=", :==, :<, :<=, :>, :>=, :!, :!=, :=~, :!~,
           :&, :|, :^, :~, :**, :>>, :<<, :%,
           :[], :[]?, :[]=, :<=>, :===,
           :"+=", :"-=", :"*=", :"/=", :"<<=", :">>=", :"**=", :"//=", :"%=",
           :"&&=", :"&=", :"&+=", :"&-=", :"&*=", :"||=", :"|=", :"^="
        highlight token.to_s, OPERATOR_COLOR, io
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
    highlight token.raw, STRING_COLOR, io unless heredoc

    while true
      token = lexer.next_string_token(token.delimiter_state)
      case token.type
      when :DELIMITER_END
        highlight token.raw, STRING_COLOR, io
        break
      when :INTERPOLATION_START
        highlight "\#{", INTERPOLATION_COLOR, io
        highlight_normal_state lexer, io, break_on_rcurly: true
        highlight "}", INTERPOLATION_COLOR, io
      else
        highlight token.raw, STRING_COLOR, io
      end
    end

    # TODO: end_highlight_class io
  end

  private def highlight_string_array(lexer, token, io)
    # TODO: start_highlight_class "s", io
    io << token.raw
    while true
      consume_space_or_newline(lexer, io)
      token = lexer.next_string_array_token
      case token.type
      when :STRING
        highlight token.raw, STRING_COLOR, io
      when :STRING_ARRAY_END
        highlight token.raw, STRING_COLOR, io
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

  private def highlight(token, color : Symbol, io)
    io << token.colorize(color)
  end
end
