# :nodoc:
class JSON::Lexer::StringBased < JSON::Lexer
  def initialize(string)
    super()
    @reader = Char::Reader.new(string)
    @number_start = 0
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
        raise "Unterminated string"
      when '\\'
        return consume_string_slow_path start_pos
      when '"'
        next_char
        break
      else
        if 0 <= current_char.ord < 32
          unexpected_char
        end
      end
    end

    if @expects_object_key
      start_pos += 1
      end_pos = current_pos - 1
      @token.string_value = @string_pool.get(@reader.string.to_unsafe + start_pos, end_pos - start_pos)
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
    @reader.string.to_slice[start_pos, end_pos - start_pos]
  end

  private def next_char_no_column_increment
    char = @reader.next_char
    if char == '\0' && @reader.pos != @reader.string.bytesize
      unexpected_char
    end
    char
  end

  private def current_char
    @reader.current_char
  end

  private def number_start
    @number_start = current_pos
  end

  private def append_number_char
    # Nothing
  end

  private def number_string
    string_range(@number_start, current_pos)
  end
end
