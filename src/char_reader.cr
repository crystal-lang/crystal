class CharReader
  getter string
  getter current_char
  getter pos

  def initialize(@string)
    @pos = 0
    @current_char = '\0'
    @current_char_width = 0
    decode_current_char
  end

  def next_char
    @pos += @current_char_width
    if @pos > @string.length
      raise IndexOutOfBounds.new
    end

    decode_current_char
  end

  def peek_next_char
    next_pos = @pos + @current_char_width

    if next_pos > @string.length
      raise IndexOutOfBounds.new
    end

    decode_char_at(next_pos) do |code_point, width|
      code_point.chr
    end
  end

  def pos=(pos)
    if pos > @string.length
      raise IndexOutOfBounds.new
    end

    @pos = pos
    decode_current_char
    pos
  end

  # private

  def decode_char_at(pos)
    if byte_at(pos) < 0x80
      yield byte_at(pos), 1
    elsif byte_at(pos) < 0xe0
      yield (byte_at(pos) & 0x1f) << 6 | (byte_at(pos+1) & 0x3f), 2
    elsif byte_at(pos) < 0xf0
      yield (byte_at(pos) & 0x0f) << 12 | (byte_at(pos+1) & 0x3f) << 6 | (byte_at(pos+2) & 0x3f), 3
    elsif byte_at(pos) < 0xf8
      yield (byte_at(pos) & 0x07) << 18 | (byte_at(pos+1) & 0x3f) << 12 | (byte_at(pos+2) & 0x3f) << 6 | (byte_at(pos+3) & 0x3f), 4
    else
      raise "Invalid byte sequence in UTF-8 string"
    end
  end

  def decode_current_char
    decode_char_at(@pos) do |code_point, width|
      @current_char_width = width
      @current_char = code_point.chr
    end
  end

  def byte_at(i)
    @string.cstr[i].to_u32
  end
end
