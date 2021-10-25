require "html"

class Crystal::SyntaxHighlighter
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

  private def consume_space_or_newline(lexer)
    while true
      char = lexer.current_char
      case char
      when '\n'
        lexer.next_char
        lexer.incr_line_number 1
        visit_whitespace char
      when .ascii_whitespace?
        lexer.next_char
        visit_whitespace char
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
          visit_token token, last_is_def
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
        visit_token token, last_is_def
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
              visit_token token, last_is_def
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

  private def highlight_delimiter_state(lexer, token, *, heredoc = false)
    visit_delimiter do
      visit_delimiter_token(token) unless heredoc
      while true
        token = lexer.next_string_token(token.delimiter_state)
        case token.type
        when :DELIMITER_END
          visit_delimiter_token(token)
          break
        when :INTERPOLATION_START
          visit_interpolation do
            highlight_normal_state lexer, break_on_rcurly: true
          end
        else
          visit_delimiter_token(token)
        end
      end
    end
  end

  private def highlight_string_array(lexer, token)
    visit_string_array do
      visit_string_array_token(token)
      while true
        consume_space_or_newline(lexer)
        token = lexer.next_string_array_token
        case token.type
        when :STRING
          visit_string_array_token(token)
        when :STRING_ARRAY_END
          visit_string_array_token(token)
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

require "./syntax_highlighter/html"
