require "html"
require "compiler/crystal/**"

abstract class Crystal::SyntaxHighlighter
  def highlight(code : String)
    lexer = Lexer.new(code)
    lexer.comments_enabled = true
    lexer.count_whitespace = true
    lexer.wants_raw = true

    highlight_normal_state lexer
  end

  def self.highlight(io : IO, code : String)
    new(io).highlight(code)
  end

  def self.highlight(code : String)
    String.build do |io|
      highlight(io, code)
    end
  end

  # Highlights *code* or returns unhighlighted *code* on error.
  #
  # Same as `.highlight(code : String)` except that any error is rescued and
  # returns unhighlighted source code.
  def self.highlight!(code : String)
    highlight(code)
  rescue
    code
  end

  abstract def render(type : TokenType, value : String)
  abstract def render_delimiter(&)
  abstract def render_interpolation(&)
  abstract def render_string_array(&)

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
      when :DELIMITER_START
        if token.delimiter_state.kind == :heredoc
          heredoc_stack << token.dup
          highlight_token token, last_is_def
        else
          highlight_delimiter_state lexer, token
        end
      when :STRING_ARRAY_START, :SYMBOL_ARRAY_START
        highlight_string_array lexer, token
      when :"}"
        break if break_on_rcurly
      when :EOF
        break
      else
        highlight_token token, last_is_def
      end

      case token.type
      when :NEWLINE
        heredoc_stack.each_with_index do |token, i|
          highlight_delimiter_state lexer, token, heredoc: true
          unless i == heredoc_stack.size - 1
            # Next token to heredoc's end is either NEWLINE or EOF.
            token = lexer.next_token

            case token.type
            when :EOF
              raise "Unterminated heredoc"
            else
              highlight_token token, last_is_def
            end
          end
        end
        heredoc_stack.clear
      when :IDENT
        if last_is_def
          last_is_def = false
        end
      end

      unless token.type == :SPACE
        last_is_def = token.keyword? :def
      end
    end
  end

  def highlight_token(token : Token, last_is_def)
    case token.type
    when :NEWLINE
      render :NEWLINE, "\n"
    when :SPACE
      render :SPACE, token.value.to_s
    when :COMMENT
      render :COMMENT, token.value.to_s
    when :NUMBER
      render :NUMBER, token.raw
    when :CHAR
      render :CHAR, token.raw
    when :SYMBOL
      render :SYMBOL, token.raw
    when :DELIMITER_START
      render :STRING, token.raw
    when :CONST, :"::"
      render :CONST, token.to_s
    when :IDENT
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
    when :+, :-, :*, :&+, :&-, :&*, :/, ://,
         :"=", :==, :<, :<=, :>, :>=, :!, :!=, :=~, :!~,
         :&, :|, :^, :~, :**, :>>, :<<, :%,
         :[], :[]?, :[]=, :<=>, :===
      render :OPERATOR, token.to_s
    when :UNDERSCORE
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
        when :DELIMITER_END
          render :DELIMITER_END, token.raw
          break
        when :INTERPOLATION_START
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
        when :STRING
          render :STRING_ARRAY_TOKEN, token.raw
        when :STRING_ARRAY_END
          render :STRING_ARRAY_END, token.raw
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
  end
end
