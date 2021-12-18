require "html"
{% unless flag?(:docs) %}
  require "compiler/crystal/syntax"
{% end %}

abstract class Crystal::SyntaxHighlighter
  # Parses *code* as Crystal source code and processes it.
  def highlight(code : String)
    lexer = Lexer.new(code)
    lexer.comments_enabled = true
    lexer.count_whitespace = true
    lexer.wants_raw = true

    highlight_normal_state lexer
  end

  # Renders *token* with text *value*.
  abstract def render(type : TokenType, value : String)

  # Renders a delimiter sequence.
  abstract def render_delimiter(&)

  # Renders an interpolation sequence.
  abstract def render_interpolation(&)

  # Renders a string array sequence.
  abstract def render_string_array(&)

  # Describes the type of a highlighter token.
  enum TokenType
    NEWLINE
    SPACE
    COMMENT
    NUMBER
    CHAR
    SYMBOL
    CONST
    STRING
    IDENT
    KEYWORD
    SELF
    PRIMITIVE_LITERAL
    OPERATOR
    DELIMITER_START
    DELIMITED_TOKEN
    DELIMITER_END
    INTERPOLATION
    STRING_ARRAY_START
    STRING_ARRAY_TOKEN
    STRING_ARRAY_END
    UNDERSCORE
    UNKNOWN
  end

  private def consume_space_or_newline(lexer)
    while true
      char = lexer.current_char
      case char
      when '\n'
        lexer.next_char
        lexer.incr_line_number 1
        render :NEWLINE, "\n"
      when .ascii_whitespace?
        lexer.next_char
        render :SPACE, char.to_s
      else
        break
      end
    end
  end

  private def highlight_normal_state(lexer, break_on_rcurly = false)
    last_is_def = false
    heredoc_stack = [] of Token

    while true
      token = lexer.next_token

      case token.type
      when .delimiter_start?
        if token.delimiter_state.kind == :heredoc
          heredoc_stack << token.dup
          highlight_token token, last_is_def
        else
          highlight_delimiter_state lexer, token
        end
      when .string_array_start?, .symbol_array_start?
        highlight_string_array lexer, token
      when .op_curlyr?
        break if break_on_rcurly

        highlight_token token, last_is_def
      when .eof?
        break
      else
        highlight_token token, last_is_def
      end

      case token.type
      when .newline?
        heredoc_stack.each_with_index do |token, i|
          highlight_delimiter_state lexer, token, heredoc: true
          unless i == heredoc_stack.size - 1
            # Next token to heredoc's end is either NEWLINE or EOF.
            token = lexer.next_token

            case token.type
            when .eof?
              raise "Unterminated heredoc"
            else
              highlight_token token, last_is_def
            end
          end
        end
        heredoc_stack.clear
      when .ident?
        if last_is_def
          last_is_def = false
        end
      end

      unless token.type.space?
        last_is_def = token.keyword? :def
      end
    end
  end

  private def highlight_token(token : Token, last_is_def)
    case token.type
    when .newline?
      render :NEWLINE, "\n"
    when .space?
      render :SPACE, token.value.to_s
    when .comment?
      render :COMMENT, token.value.to_s
    when .number?
      render :NUMBER, token.raw
    when .char?
      render :CHAR, token.raw
    when .symbol?
      render :SYMBOL, token.raw
    when .delimiter_start?
      render :STRING, token.raw
    when .const?, .op_colon_colon?
      render :CONST, token.to_s
    when .ident?
      if last_is_def
        render :IDENT, token.to_s
      else
        case token.value
        when :def, :if, :else, :elsif, :end,
             :class, :module, :include, :extend,
             :while, :until, :do, :yield, :return, :unless, :next, :break, :begin,
             :lib, :fun, :type, :struct, :union, :enum, :macro, :out, :require,
             :case, :when, :select, :then, :of, :abstract, :rescue, :ensure, :is_a?,
             :alias, :pointerof, :sizeof, :instance_sizeof, :offsetof, :as, :as?, :typeof, :for, :in,
             :with, :super, :private, :asm, :nil?, :protected, :uninitialized, "new",
             :annotation, :verbatim
          render :KEYWORD, token.to_s
        when :true, :false, :nil
          render :PRIMITIVE_LITERAL, token.to_s
        when :self
          render :SELF, token.to_s
        else
          render :UNKNOWN, token.to_s
        end
      end
    when .op_plus?, .op_minus?, .op_star?, .op_amp_plus?, .op_amp_minus?, .op_amp_star?, .op_slash?, .op_slash_slash?,           # + - * &+ &- &* / //
         .op_eq?, .op_eq_eq?, .op_lt?, .op_lt_eq?, .op_gt?, .op_gt_eq?, .op_bang?, .op_bang_eq?, .op_eq_tilde?, .op_bang_tilde?, # = == < <= > >= ! != =~ !~
         .op_amp?, .op_bar?, .op_caret?, .op_tilde?, .op_star_star?, .op_gt_gt?, .op_lt_lt?, .op_percent?,                       # & | ^ ~ ** >> << %
         .op_squarel_squarer?, .op_squarel_squarer_question?, .op_squarel_squarer_eq?, .op_lt_eq_gt?, .op_eq_eq_eq?              # [] []? []= <=> ===
      render :OPERATOR, token.to_s
    when .underscore?
      render :UNDERSCORE, "_"
    else
      render :UNKNOWN, token.to_s
    end
  end

  private def highlight_delimiter_state(lexer, token, *, heredoc = false)
    render_delimiter do
      render :DELIMITER_START, token.raw unless heredoc
      while true
        token = lexer.next_string_token(token.delimiter_state)
        case token.type
        when .delimiter_end?
          render :DELIMITER_END, token.raw
          break
        when .interpolation_start?
          render_interpolation do
            highlight_normal_state lexer, break_on_rcurly: true
          end
        else
          render :DELIMITED_TOKEN, token.raw
        end
      end
    end
  end

  private def highlight_string_array(lexer, token)
    render_string_array do
      render :STRING_ARRAY_START, token.raw
      while true
        consume_space_or_newline(lexer)
        token = lexer.next_string_array_token
        case token.type
        when .string?
          render :STRING_ARRAY_TOKEN, token.raw
        when .string_array_end?
          render :STRING_ARRAY_END, token.raw
          break
        when .eof?
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
  end
end
