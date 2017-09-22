require "csv"

# A CSV lexer lets you consume a CSV token by token. You can use this to efficiently
# parse a CSV without the need to allocate intermediate arrays.
#
# ```
# require "csv"
#
# lexer = CSV::Lexer.new "one,two\nthree"
# lexer.next_token # => CSV::Token(@kind=Cell, @value="one")
# lexer.next_token # => CSV::Token(@kind=Cell, @value="two")
# lexer.next_token # => CSV::Token(@kind=Newline, @value="two")
# lexer.next_token # => CSV::Token(@kind=Cell, @value="three")
# lexer.next_token # => CSV::Token(@kind=Eof, @value="three")
# ```
abstract class CSV::Lexer
  # Creates a CSV lexer from a `String`.
  def self.new(string : String, separator = DEFAULT_SEPARATOR, quote_char = DEFAULT_QUOTE_CHAR)
    StringBased.new(string, separator, quote_char)
  end

  # Creates a CSV lexer from an `IO`.
  def self.new(io : IO, separator = DEFAULT_SEPARATOR, quote_char = DEFAULT_QUOTE_CHAR)
    IOBased.new(io, separator, quote_char)
  end

  # Returns the current `Token`.
  getter token : Token
  getter separator : Char
  getter quote_char : Char

  # :nodoc:
  def initialize(@separator : Char = DEFAULT_SEPARATOR, @quote_char : Char = DEFAULT_QUOTE_CHAR)
    @token = Token.new
    @buffer = IO::Memory.new
    @column_number = 1
    @line_number = 1
    @last_empty_column = false
  end

  private abstract def consume_unquoted_cell
  private abstract def next_char_no_column_increment
  private abstract def current_char

  # Rewinds this lexer to its beginning.
  abstract def rewind

  # Returns the next `Token` in this CSV.
  def next_token
    if @last_empty_column
      @last_empty_column = false
      @token.kind = Token::Kind::Cell
      @token.value = ""
      return @token
    end

    case current_char
    when '\0'
      @token.kind = Token::Kind::Eof
    when @separator
      @token.kind = Token::Kind::Cell
      @token.value = ""
      check_last_empty_column
    when '\r'
      @token.kind =
        case next_char
        when '\0'
          Token::Kind::Eof
        when '\n'
          case next_char
          when '\0'
            Token::Kind::Eof
          else
            Token::Kind::Newline
          end
        else
          Token::Kind::Newline
        end
    when '\n'
      @token.kind = next_char == '\0' ? Token::Kind::Eof : Token::Kind::Newline
    when @quote_char
      @token.kind = Token::Kind::Cell
      @token.value = consume_quoted_cell
    else
      @token.kind = Token::Kind::Cell
      @token.value = consume_unquoted_cell
    end
    @token
  end

  private def consume_quoted_cell
    @buffer.clear
    while true
      case char = next_char
      when '\0'
        raise "Unclosed quote"
        break
      when @quote_char
        case next_char
        when @separator
          check_last_empty_column
          break
        when '\r', '\n', '\0'
          break
        when @quote_char
          @buffer << @quote_char
        else
          raise "Expecting comma, newline or end, not #{current_char.inspect}"
        end
      else
        @buffer << char
      end
    end
    @buffer.to_s
  end

  private def check_last_empty_column
    case next_char
    when '\r', '\n', '\0'
      @last_empty_column = true
    end
  end

  private def next_char
    @column_number += 1
    char = next_char_no_column_increment
    if char == '\n' || char == '\r'
      @column_number = 0
      @line_number += 1
    end
    char
  end

  private def raise(msg)
    ::raise CSV::MalformedCSVError.new(msg, @line_number, @column_number)
  end
end
