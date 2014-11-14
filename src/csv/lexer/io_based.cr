class CSV::Lexer::IOBased < CSV::Lexer
  def initialize(io)
    super()
    @io = io
    @current_char = @io.read_char || '\0'
  end

  private def consume_unquoted_cell
    @buffer.clear
    while true
      case current_char
      when ','
        check_last_empty_column
        break
      when '\n', '\0'
        break
      when '"'
        raise "unexpected quote"
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
