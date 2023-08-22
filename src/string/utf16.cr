class String
  # Returns the UTF-16 encoding of the given *string*.
  #
  # Invalid chars (in the range U+D800..U+DFFF) are encoded with the
  # unicode replacement char value `0xfffd`.
  #
  # The byte following the end of this slice (but not included in it) is defined
  # to be zero. This allows passing the result of this function into C functions
  # that expect a null-terminated `UInt16*`.
  #
  # ```
  # "hi 𐂥".to_utf16 # => Slice[104_u16, 105_u16, 32_u16, 55296_u16, 56485_u16]
  # ```
  def to_utf16 : Slice(UInt16)
    if ascii_only?
      # size == bytesize, so each char fits in one UInt16

      # This is essentially equivalent to `to_slice.map(&.to_u16)` but also makes
      # sure to allocate a null byte after the string.
      slice = Slice(UInt16).new(bytesize + 1) do |i|
        if i == bytesize
          0_u16
        else
          to_unsafe[i].to_u16
        end
      end
      return slice[0, bytesize]
    end

    # size < bytesize, so we need to count the number of characters that are
    # two UInt16 wide.
    u16_size = 0
    each_char do |char|
      u16_size += char.ord < 0x1_0000 ? 1 : 2
    end

    # Allocate one extra character for trailing null
    slice = Slice(UInt16).new(u16_size + 1)

    i = 0
    each_char do |char|
      ord = char.ord
      if ord <= 0xd800 || (0xe000 <= ord < 0x1_0000)
        # One UInt16 is enough
        slice[i] = ord.to_u16
      elsif ord >= 0x1_0000
        # Needs surrogate pair
        ord -= 0x1_0000
        slice[i] = 0xd800_u16 + ((ord >> 10) & 0x3ff) # Keep top 10 bits
        i += 1
        slice[i] = 0xdc00_u16 + (ord & 0x3ff) # Keep low 10 bits
      else
        # Invalid char: use replacement
        slice[i] = 0xfffd_u16
      end
      i += 1
    end

    # Append null byte
    slice[i] = 0_u16

    slice[0, u16_size]
  end

  # Decodes the given *slice* UTF-16 sequence into a String.
  #
  # Invalid values are encoded using the unicode replacement char with
  # codepoint `0xfffd`.
  #
  # ```
  # slice = Slice[104_u16, 105_u16, 32_u16, 55296_u16, 56485_u16]
  # String.from_utf16(slice) # => "hi 𐂥"
  # ```
  def self.from_utf16(slice : Slice(UInt16)) : String
    bytesize = 0
    size = 0

    each_utf16_char(slice) do |char|
      bytesize += char.bytesize
      size += 1
    end

    String.new(bytesize) do |buffer|
      each_utf16_char(slice) do |char|
        char.each_byte do |byte|
          buffer.value = byte
          buffer += 1
        end
      end
      {bytesize, size}
    end
  end

  # Decodes the given *slice* UTF-16 sequence into a String and returns the
  # pointer after reading. The string ends when a zero value is found.
  #
  # ```
  # slice = Slice[104_u16, 105_u16, 0_u16, 55296_u16, 56485_u16, 0_u16]
  # String.from_utf16(slice) # => "hi\0000𐂥\u0000"
  # pointer = slice.to_unsafe
  # string, pointer = String.from_utf16(pointer)
  # string # => "hi"
  # string, pointer = String.from_utf16(pointer)
  # string # => "𐂥"
  # ```
  #
  # Invalid values are encoded using the unicode replacement char with
  # codepoint `0xfffd`.
  def self.from_utf16(pointer : Pointer(UInt16)) : {String, Pointer(UInt16)}
    bytesize = 0
    size = 0

    each_utf16_char(pointer) do |char|
      bytesize += char.bytesize
      size += 1
    end

    string = String.new(bytesize) do |buffer|
      pointer = each_utf16_char(pointer) do |char|
        char.each_byte do |byte|
          buffer.value = byte
          buffer += 1
        end
      end
      {bytesize, size}
    end

    {string, pointer + 1}
  end

  # Yields each decoded char in the given slice.
  private def self.each_utf16_char(slice : Slice(UInt16), &)
    i = 0
    while i < slice.size
      byte = slice[i].to_i
      if byte < 0xd800 || byte >= 0xe000
        # One byte
        codepoint = byte
      elsif byte < 0xdc00 &&
            (i + 1) < slice.size &&
            0xdc00 <= slice[i + 1] <= 0xdfff
        # Surrogate pair
        codepoint = (byte << 10) &+ slice[i + 1] &- 0x35fdc00
        i += 1
      else
        # Invalid byte
        codepoint = 0xfffd
      end

      yield codepoint.unsafe_chr

      i += 1
    end
  end

  # Yields each decoded char in the given pointer, stopping at the first null byte.
  private def self.each_utf16_char(pointer : Pointer(UInt16), &) : Pointer(UInt16)
    loop do
      byte = pointer.value.to_i
      break if byte == 0

      if byte < 0xd800 || byte >= 0xe000
        # One byte
        codepoint = byte
      elsif byte < 0xdc00 &&
            0xdc00 <= (pointer + 1).value <= 0xdfff
        # Surrogate pair
        pointer = pointer + 1
        codepoint = (byte << 10) &+ pointer.value &- 0x35fdc00
      else
        # Invalid byte
        codepoint = 0xfffd
      end

      yield codepoint.unsafe_chr

      pointer = pointer + 1
    end

    pointer
  end
end
