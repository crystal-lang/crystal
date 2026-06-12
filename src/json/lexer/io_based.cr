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

  # Same byte-oriented loop as `consume_string_tail`, but without building
  # a result, since the value is being skipped.
  private def consume_string_skip
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

  # Consumes the digit run byte by byte, avoiding char decoding. The
  # first non-digit byte ends the run and becomes the current char.
  private def consume_digits : Char
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
