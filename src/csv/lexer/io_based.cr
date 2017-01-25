require "csv"

# :nodoc:
class CSV::Lexer::IOBased < CSV::Lexer
  def initialize(@io : IO, separator = DEFAULT_SEPARATOR, quote_char = DEFAULT_QUOTE_CHAR)
    super(separator, quote_char)
    @current_char = @io.read_char || '\0'
  end

  def rewind
    @io.rewind
    @current_char = @io.read_char || '\0'
  end

  private def consume_unquoted_cell
    @buffer.clear
    while true
      case current_char
      when @separator
        check_last_empty_column
        break
      when '\r', '\n', '\0'
        break
      when @quote_char
        raise "Unexpected quote"
      else
        @buffer << current_char
        next_char
      end
    end
    @buffer.to_s
  end

  private getter current_char

  private def next_char_no_column_increment
    @current_char = @io.read_char || '\0'
  end

  private def consume_string
    consume_string_with_buffer
  end
end
