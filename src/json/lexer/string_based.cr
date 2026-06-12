# :nodoc:
class JSON::Lexer::StringBased < JSON::Lexer
  def initialize(string)
    super()
    @reader = Char::Reader.new(string)
    @number_start = 0
  end

  # Consumes a string by remembering the start position of it and then
  # doing a substring of the original string.
  # If we find an escape sequence (\) we can't do that anymore so we
  # go through a slow path where we accumulate everything in a buffer
  # to build the resulting string.
  private def consume_string
    start_pos = current_pos
    byte, pos = scan_string_bytes(start_pos + 1)

    if byte == '\\'.ord
      return consume_string_slow_path start_pos
    end

    if @expects_object_key
      @token.string_value = @string_pool.get(@reader.string.to_unsafe + start_pos + 1, pos - start_pos - 1)
    else
      @token.string_value = string_range(start_pos + 1, pos)
    end
  end

  # Same byte-oriented scan as `consume_string`, but without building a
  # result, since the value is being skipped.
  private def consume_string_skip
    loop do
      byte, _ = scan_string_bytes(current_pos + 1)
      return if byte == '"'.ord
      consume_string_escape_sequence
    end
  end

  private def consume_string_slow_path(start_pos)
    @buffer.clear
    loop do
      @buffer.write slice_range(start_pos + 1, current_pos)
      @buffer << consume_string_escape_sequence
      start_pos = current_pos
      byte, pos = scan_string_bytes(start_pos + 1)
      if byte == '"'.ord
        @buffer.write slice_range(start_pos + 1, pos)
        break
      end
    end
    @token.string_value =
      if @expects_object_key
        @string_pool.get(@buffer)
      else
        @buffer.to_s
      end
  end

  # Scans the raw bytes of the source string starting at `pos` until a
  # closing quote or a backslash, raising on control characters or end of
  # input. Returns the found byte and its position, leaving the reader on
  # the backslash, or right after the closing quote, respectively.
  #
  # Scanning bytes instead of chars is safe because every byte that
  # affects lexing is ASCII. Multi-byte characters are passed through
  # unchanged (as byte slices of the source string). Only `@column_number`
  # requires counting characters, done by skipping UTF-8 continuation
  # bytes.
  private def scan_string_bytes(pos) : {UInt8, Int32}
    string = @reader.string
    ptr = string.to_unsafe
    bytesize = string.bytesize
    char_count = 0

    loop do
      if pos >= bytesize
        @column_number += char_count + 1
        @reader.pos = bytesize
        raise "Unterminated string"
      end

      byte = ptr[pos]
      case byte
      when '"'
        @column_number += char_count + 2
        @reader.pos = pos + 1
        return {byte, pos}
      when '\\'
        @column_number += char_count + 1
        @reader.pos = pos
        return {byte, pos}
      else
        if byte < ' '.ord
          @column_number += char_count + 1
          @reader.pos = pos
          unexpected_char
        end
        # Only count initial bytes of a UTF-8 codepoint
        char_count += 1 if byte & 0xc0 != 0x80
      end
      pos += 1
    end
  end

  private def current_pos
    @reader.pos
  end

  def string_range(start_pos : Int, end_pos : Int) : String
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  def slice_range(start_pos : Int, end_pos : Int) : Bytes
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
