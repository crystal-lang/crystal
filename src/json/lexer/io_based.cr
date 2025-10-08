# :nodoc:
class JSON::Lexer::IOBased < JSON::Lexer
  def initialize(@io : IO)
    super()
    @current_char = @io.read_char || '\0'
  end

  private getter current_char

  private def next_char_no_column_increment
    @current_char = @io.read_char || '\0'
  end

  private def consume_string
    consume_string_with_buffer
  end

  private def number_start
    @buffer.clear
  end

  private def append_number_char
    @buffer << current_char
  end

  private def number_string
    @buffer.to_s
  end
end
