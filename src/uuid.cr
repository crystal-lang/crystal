
require "secure_random"

private def assert_hex_pair_at!(value : String, i)
  unless value[i].hex? && value[i + 1].hex?
    raise ArgumentError.new [
      "Invalid hex character at position #{i * 2} or #{i * 2 + 1}",
      "expected '0' to '9', 'a' to 'f' or 'A' to 'F'."
    ].join(", ")
  end
end

# Universally Unique Identifier.
struct UUID

  enum Version
    Unknown
    V1
    V2
    V3
    V4
    V5
  end

  @data = StaticArray(UInt8, 16).new

  def initialize(bytes : Slice(UInt8))
    raise ArgumentError.new "Invalid bytes length #{bytes.size}, expected 16." if bytes.size != 16
    @data.to_unsafe.copy_from bytes
  end

  def initialize(version = Version::V4)
    case version
    when Version::V4
      @data.to_unsafe.copy_from SecureRandom.random_bytes(16).to_unsafe, 16
      @data[6] = (@data[6] & 0x0f) | 0x40
      @data[8] = (@data[8] & 0x3f) | 0x80
    else
      raise ArgumentError.new "Unsupported version #{version}."
    end
  end

  def initialize(value : String)
    case value.size
    when 36 # with hyphens
      [8, 13, 18, 23].each do |offset|
        if value[offset] != '-'
          raise ArgumentError.new "Invalid UUID string format, expected hyphen at char #{offset}."
        end
      end
      [0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34].each_with_index do |offset, i|
        assert_hex_pair_at! value, offset
        @data[i] = value[offset, 2].to_u8(16)
      end
    when 32 # without hyphens
      16.times do |i|
        assert_hex_pair_at! value, i * 2
        @data[i] = value[i * 2, 2].to_u8(16)
      end
    else
      raise ArgumentError.new "Invalid string length #{value.size} for UUID, expected 32 (hex) or 36 (hyphenated hex)."
    end
  end

  def to_slice
    Slice(UInt8).new to_unsafe, 16
  end

  def to_unsafe
    @data.to_unsafe
  end

  def to_s(io : IO)
    io << to_s(true)
  end

  def to_s(hyphenated = true)
    slice = to_slice
    if hyphenated
      String.new(36) do |buffer|
        buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
        slice[0, 4].hexstring(buffer + 0)
        slice[4, 2].hexstring(buffer + 9)
        slice[6, 2].hexstring(buffer + 14)
        slice[8, 2].hexstring(buffer + 19)
        slice[10, 6].hexstring(buffer + 24)
        {36, 36}
      end
    else
      slice.hexstring
    end
  end

  def ==(other : String)
    self == UUID.new other
  end

  def ==(other : Slice(UInt8))
    to_slice == other
  end

  def ==(other : StaticArray(UInt8, 16))
    self.==(Slice(UInt8).new other.to_unsafe, 16)
  end

end
