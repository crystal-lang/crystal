class CharReader
  getter current_char
  getter pos

  def initialize(@string)
    @pos = 0
    @current_char = 0
    @current_char_width = 0
    decode_current_char
  end

  def next_char
    if @pos >= @string.length
      raise IndexOutOfBounds.new
    end

    @pos += @current_char_width
    decode_current_char
  end

  # private

  def decode_current_char
    if byte_at(@pos) < 0x80
      @current_char_width = 1
      @current_char = byte_at(@pos)
    elsif byte_at(@pos) < 0xe0
      @current_char_width = 2
      @current_char = (byte_at(@pos) & 0x1f) << 6 | (byte_at(@pos+1) & 0x3f)
    elsif byte_at(@pos) < 0xf0
      @current_char_width = 3
      @current_char = (byte_at(@pos) & 0x0f) << 12 | (byte_at(@pos+1) & 0x3f) << 6 | (byte_at(@pos+2) & 0x3f)
    elsif byte_at(@pos) < 0xf8
      @current_char_width = 4
      @current_char = (byte_at(@pos) & 0x07) << 18 | (byte_at(@pos+1) & 0x3f) << 12 | (byte_at(@pos+2) & 0x3f) << 6 | (byte_at(@pos+3) & 0x3f)
    else
      raise "Invalid byte sequence in UTF-8 string"
    end
  end

  def byte_at(i)
    @string.cstr[i].to_u32
  end
end
