require "csv"

# :nodoc:
class CSV::Lexer::StringBased < CSV::Lexer
  def initialize(string, separator = DEFAULT_SEPARATOR, quote_char = DEFAULT_QUOTE_CHAR)
    super(separator, quote_char)
    @reader = Char::Reader.new(string)
    if @reader.current_char == '\n'
      @line_number += 1
      @column_number = 0
    end
  end

  def rewind
    @reader.pos = 0
  end

  private def consume_unquoted_cell
    start_pos = @reader.pos
    end_pos = start_pos
    while true
      case next_char
      when @separator
        end_pos = @reader.pos
        check_last_empty_column
        break
      when '\r', '\n', '\0'
        end_pos = @reader.pos
        break
      when @quote_char
        raise "Unexpected quote"
      end
    end
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  private def next_char_no_column_increment
    @reader.next_char
  end

  private def current_char
    @reader.current_char
  end
end
