# :nodoc:
class JSON::Lexer::IOBased < JSON::Lexer
  def initialize(@io : IO)
    super()
    @current_char = @io.read_byte.try(&.chr) || '\0'
  end

  private getter current_char

  private def next_char_no_column_increment
    @current_char = @io.read_byte.try(&.chr) || '\0'
  end

  private def consume_string
    peek = @io.peek
    if !peek || peek.empty?
      return consume_string_with_buffer
    end

    pos = 0

    while true
      if pos >= peek.size
        # We don't have enough data in the peek buffer to create a string:
        # default to the slow method
        @column_number -= pos
        return consume_string_with_buffer
      end

      char = peek[pos]
      case char
      when '\\'
        # If we find an escape character, go to the slow method
        return consume_string_at_escape_char(peek, pos)
      when '"'
        @column_number += 1
        @io.skip(pos + 1)
        @current_char = @io.read_byte.try(&.chr) || '\0'
        break
      else
        if 0 <= current_char.ord < 32
          unexpected_char
        else
          pos += 1
          @column_number += 1
        end
      end
    end

    @token.string_value =
      if @expects_object_key
        @string_pool.get(peek.to_unsafe, pos)
      else
        String.new(peek.to_unsafe, pos)
      end
  end

  private def consume_string_at_escape_char(peek, pos)
    consume_string_with_buffer do
      @buffer.write peek[0, pos]
      @io.skip(pos)
    end
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
