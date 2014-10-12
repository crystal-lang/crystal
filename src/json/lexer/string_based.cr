class Json::Lexer::StringBased < Json::Lexer
  def initialize(string)
    super()
    @reader = CharReader.new(string)
  end

  # Consume a string by remembering the start position of it and then
  # doing a substring of the original string.
  # If we find an escape sequence (\) we can't do that anymore so we
  # go through a slow path where we accumulate everything in a buffer
  # to build the resulting string.
  private def consume_string
    start_pos = current_pos

    while true
      case char = next_char
      when '\0'
        raise "unterminated string"
      when '\\'
        return consume_string_slow_path start_pos
      when '"'
        next_char
        break
      end
    end

    if @expects_object_key
      start_pos += 1
      end_pos = current_pos - 1
      @token.string_value = @string_pool.get(@reader.string.cstr + start_pos, end_pos - start_pos)
    else
      @token.string_value = string_range(start_pos + 1, current_pos - 1)
    end
  end

  private def consume_string_slow_path(start_pos)
    consume_string_with_buffer do
      @buffer.write slice_range(start_pos + 1, current_pos)
      @buffer << consume_string_escape_sequence
    end
  end

  private def current_pos
    @reader.pos
  end

  def string_range(start_pos, end_pos)
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  def slice_range(start_pos, end_pos)
    @reader.string.to_slice.to_slice[start_pos, end_pos - start_pos]
  end

  private def next_char_no_column_increment
    @reader.next_char
  end

  private def current_char
    @reader.current_char
  end
end
