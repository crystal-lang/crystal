class String
  # Returns the UTF-16 encoding of the given *string*.
  #
  # Invalid chars (in the range U+D800..U+DFFF) are encoded with the
  # unicode replacement char value `0xfffd`.
  #
  # ```
  # "hi 𐂥".to_utf16 # => Slice[104_u16, 105_u16, 32_u16, 55296_u16, 56485_u16]
  # ```
  def to_utf16 : Slice(UInt16)
    size = 0
    each_char do |char|
      size += char.ord < 0x10000 ? 1 : 2
    end

    slice = Slice(UInt16).new(size)

    i = 0
    each_char do |char|
      ord = char.ord
      if ord <= 0xd800 || (0xe000 <= ord < 0x10000)
        # One UInt16 is enough
        slice[i] = ord.to_u16
      elsif ord >= 0x10000
        # Needs surrogate pair
        ord -= 0x10000
        slice[i] = 0xd800_u16 + ((ord >> 10) & 0x3ff) # Keep top 10 bits
        i += 1
        slice[i] = 0xdc00_u16 + (ord & 0x3ff) # Keep low 10 bits
      else
        # Invalid char: use replacement
        slice[i] = 0xfffd_u16
      end
      i += 1
    end

    slice
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

  # Yields each decoded char in the given slice.
  private def self.each_utf16_char(slice : Slice(UInt16))
    i = 0
    while i < slice.size
      byte = slice[i].to_i
      if byte < 0xd800 || byte >= 0xe000
        # One byte
        codepoint = byte
      elsif 0xd800 <= byte < 0xdc00 &&
            (i + 1) < slice.size &&
            0xdc00 <= slice[i + 1] <= 0xdfff
        # Surrougate pair
        codepoint = ((byte - 0xd800) << 10) + (slice[i + 1] - 0xdc00) + 0x10000
        i += 1
      else
        # Invalid byte
        codepoint = 0xfffd
      end

      yield codepoint.chr

      i += 1
    end
  end
end
