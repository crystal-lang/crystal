class Json::Lexer::IOBased < Json::Lexer
  def initialize(io)
    super()
    @io = io
    @current_char = @io.read_char || '\0'
  end

  private getter current_char

  private def next_char_no_column_increment
    @current_char = @io.read_char || '\0'
  end

  private def consume_string
    consume_string_with_buffer
  end
end
