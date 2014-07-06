# A CharReader allows iterating a String by Chars.
#
# As soon as you instantiate a CharReader it will decode the first
# char in the String, which can be accesed by invoking `current_char`.
# At this point `pos`, the current position in the string, will equal zero.
# Successive calls to `next_char` return the next chars in the string,
# advancing `pos`.
#
# Note that the null character '\0' will be returned in `current_char` when
# the end is reached (as well as when the string is empty). Thus, `has_next?`
# will return `false` only when `pos` is equal to the string's length, in which
# case `current_char` will always be '\0'.
struct CharReader
  include Enumerable(Char)

  getter string
  getter current_char
  getter pos

  def initialize(@string)
    @pos = 0
    @current_char = '\0'
    @current_char_width = 0
    @end = false
    decode_current_char
  end

  def has_next?
    !@end
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

  def each
    while has_next?
      yield current_char
      @pos += @current_char_width
      decode_current_char
    end
    self
  end

  # private

  def decode_char_at(pos)
    first = byte_at(pos)
    if first < 0x80
      return yield first, 1
    end

    second = byte_masked_at(pos + 1)
    if first < 0xe0
      return yield (first & 0x1f) << 6 | second, 2
    end

    third = byte_masked_at(pos + 2)
    if first < 0xf0
      return yield (first & 0x0f) << 12 | (second << 6) | third, 3
    end

    fourth = byte_masked_at(pos + 3)
    if first < 0xf8
      return yield (first & 0x07) << 18 | (second << 12) | (third << 6) | fourth, 4
    end

    raise "Invalid byte sequence in UTF-8 string"
  end

  def decode_current_char
    decode_char_at(@pos) do |code_point, width|
      @current_char_width = width
      @end = @pos == @string.length
      @current_char = code_point.chr
    end
  end

  def byte_at(i)
    @string.cstr[i].to_u32
  end

  def byte_masked_at(i)
    byte_at(i) & 0x3f
  end
end
