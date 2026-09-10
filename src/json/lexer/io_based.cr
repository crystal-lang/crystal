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
    # When the IO is peekable, scan its raw bytes instead of reading byte
    # by byte: `#skip` only ever consumes what was lexed, so the IO is
    # left exactly where `#read_utf8_byte` would have left it. The peek
    # buffer can't be used when a decoder transcodes the raw bytes.
    if !@io.has_non_utf8_encoding? && (peek = @io.peek)
      consume_string_peek(peek)
    else
      consume_string_with_buffer
    end
  end

  private def consume_string_peek(peek : Bytes) : Nil
    pos = 0
    char_count = 0

    # Fast path: the whole string is escape-free and inside the currently
    # peeked bytes, so the value is built straight from those bytes,
    # without copying through `@buffer`.
    while pos < peek.size
      byte = peek.unsafe_fetch(pos)
      case byte
      when '"'
        value =
          if @expects_object_key
            @string_pool.get(peek.to_unsafe, pos)
          else
            String.new(peek[0, pos])
          end
        @io.skip(pos + 1)
        @column_number += char_count + 1
        next_char
        @token.string_value = value
        return
      when '\\'
        break
      else
        if byte < ' '.ord
          @column_number += char_count + 1
          unexpected_char byte.unsafe_chr
        end
        # Only count initial bytes of a UTF-8 codepoint
        char_count += 1 if byte & 0xc0 != 0x80
      end
      pos += 1
    end

    # The string contains an escape sequence or crosses the peeked window, so we
    # shovel it into `@buffer` chunk-by-chunk
    @buffer.clear
    loop do
      @buffer.write peek[0, pos]
      if pos < peek.size # stopped at a backslash
        @io.skip(pos + 1)
        @column_number += char_count + 1
        @buffer << consume_string_escape_sequence
      else # consumed the whole peeked window
        @io.skip(pos)
        @column_number += char_count
      end

      peek = @io.peek
      unless peek
        # The IO is no longer peekable for whatever reason, finish reading
        # byte by byte
        return consume_string_tail
      end
      if peek.empty?
        @column_number += 1
        raise "Unterminated string"
      end

      pos = 0
      char_count = 0
      while pos < peek.size
        byte = peek.unsafe_fetch(pos)
        case byte
        when '"'
          @buffer.write peek[0, pos]
          value =
            if @expects_object_key
              @string_pool.get(@buffer)
            else
              @buffer.to_s
            end
          @io.skip(pos + 1)
          @column_number += char_count + 1
          next_char
          @token.string_value = value
          return
        when '\\'
          break
        else
          if byte < ' '.ord
            @column_number += char_count + 1
            unexpected_char byte.unsafe_chr
          end
          # Only count initial bytes of a UTF-8 codepoint
          char_count += 1 if byte & 0xc0 != 0x80
        end
        pos += 1
      end
    end
  end

  # Consumes the rest of the string by reading raw UTF-8 bytes instead of
  # decoded chars: every byte that affects lexing is ASCII, and the bytes
  # of multi-byte characters can be appended to the buffer verbatim.
  # `IO#read_utf8_byte` goes through the IO's decoder, so this works for
  # any source encoding.
  private def consume_string_tail
    while true
      case byte = @io.read_utf8_byte
      when nil
        @column_number += 1
        raise "Unterminated string"
      when '"'
        @column_number += 1
        next_char
        break
      when '\\'
        @column_number += 1
        @buffer << consume_string_escape_sequence
      else
        # Only the leading byte of each UTF-8 character count
        @column_number += 1 if byte & 0xc0 != 0x80
        unexpected_char byte.unsafe_chr if byte < 0x20
        @buffer.write_byte byte
      end
    end
    if @expects_object_key
      @token.string_value = @string_pool.get(@buffer)
    else
      @token.string_value = @buffer.to_s
    end
  end

  # Same byte-oriented scan as `consume_string_peek`, but without building
  # a result since the value is being skipped.
  private def consume_string_skip
    unless !@io.has_non_utf8_encoding? && (peek = @io.peek)
      return skip_string_tail
    end

    loop do
      pos = 0
      char_count = 0
      while pos < peek.size
        byte = peek.unsafe_fetch(pos)
        case byte
        when '"'
          @io.skip(pos + 1)
          @column_number += char_count + 1
          next_char
          return
        when '\\'
          break
        else
          if byte < 0x20
            @column_number += char_count + 1
            unexpected_char byte.unsafe_chr
          end
          # Only track the initial bytes of each UTF-8 character
          char_count += 1 if byte & 0xc0 != 0x80
        end
        pos += 1
      end

      if pos < peek.size # stopped at a backslash
        @io.skip(pos + 1)
        @column_number += char_count + 1
        consume_string_escape_sequence
      else
        @io.skip(pos)
        @column_number += char_count
      end

      peek = @io.peek
      unless peek
        # The IO is no longer peekable: finish reading byte by byte
        return skip_string_tail
      end
      if peek.empty?
        @column_number += 1
        raise "Unterminated string"
      end
    end
  end

  # Same byte-oriented loop as `consume_string_tail`, but without building
  # a result, since the value is being skipped.
  private def skip_string_tail
    while true
      case byte = @io.read_utf8_byte
      when nil
        @column_number += 1
        raise "Unterminated string"
      when '"'
        @column_number += 1
        next_char
        break
      when '\\'
        @column_number += 1
        consume_string_escape_sequence
      else
        @column_number += 1 if byte & 0xc0 != 0x80
        unexpected_char byte.unsafe_chr if byte < 0x20
      end
    end
  end

  # Scans the digit run in the IO's peek buffer, appending whole digit
  # spans to `@buffer` at once instead of one byte at a time.
  private def consume_digits : Char
    return consume_digits_slow if @io.has_non_utf8_encoding?

    loop do
      peek = @io.peek
      return consume_digits_slow unless peek # not peekable: read byte by byte
      return next_char if peek.empty?

      pos = 0
      while pos < peek.size && '0'.ord <= peek.unsafe_fetch(pos) <= '9'.ord
        pos += 1
      end

      @buffer.write peek[0, pos]
      @io.skip(pos)
      @column_number += pos

      # The digit run only ends inside the peeked window; otherwise peek
      # again for the continuation.
      return next_char if pos < peek.size
    end
  end

  # Consumes the digit run byte by byte, avoiding char decoding. The
  # first non-digit byte ends the run and becomes the current char.
  private def consume_digits_slow : Char
    while true
      byte = @io.read_utf8_byte
      @column_number += 1
      if byte && '0'.ord <= byte <= '9'.ord
        @buffer.write_byte byte
      else
        return set_current_char(byte)
      end
    end
  end

  # Restores `current_char` from a byte already consumed from the IO,
  # reading the continuation bytes when it starts a multi-byte character.
  private def set_current_char(byte : UInt8?) : Char
    @current_char =
      case byte
      when nil
        '\0'
      when .< 0x80_u8
        byte.unsafe_chr
      else
        size = byte < 0xe0_u8 ? 2 : byte < 0xf0_u8 ? 3 : 4
        codepoint = (byte & (0x7f_u8 >> size)).to_u32
        (size - 1).times do
          continuation = @io.read_utf8_byte
          break unless continuation
          codepoint = (codepoint << 6) | (continuation & 0x3f_u8)
        end
        codepoint.unsafe_chr
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
