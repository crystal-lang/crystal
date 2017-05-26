struct UUID
  # Raises `ArgumentError` if string `value` at index `i` doesn't contain hex digit followed by another hex digit.
  # TODO: Move to String#digits?(base, offset, size) or introduce strict String#[index, size].to_u8(base)! which doesn't
  #       allow non-digits. The problem it solves is that " 1".to_u8(16) is fine but if it appears inside hexstring
  #       it's not correct and there should be stdlib function to support it, without a need to build this kind of
  #       helpers.
  def self.string_has_hex_pair_at!(value : String, i)
    unless value[i].hex? && value[i + 1].hex?
      raise ArgumentError.new [
        "Invalid hex character at position #{i * 2} or #{i * 2 + 1}",
        "expected '0' to '9', 'a' to 'f' or 'A' to 'F'.",
      ].join(", ")
    end
  end

  # Creates new UUID by decoding `value` string from hyphenated (ie. `ba714f86-cac6-42c7-8956-bcf5105e1b81`),
  # hexstring (ie. `89370a4ab66440c8add39e06f2bb6af6`) or URN (ie. `urn:uuid:3f9eaf9e-cdb0-45cc-8ecb-0e5b2bfb0c20`)
  # format.
  def decode(value : String)
    case value.size
    when 36 # Hyphenated
      [8, 13, 18, 23].each do |offset|
        if value[offset] != '-'
          raise ArgumentError.new "Invalid UUID string format, expected hyphen at char #{offset}."
        end
      end
      [0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34].each_with_index do |offset, i|
        ::UUID.string_has_hex_pair_at! value, offset
        @bytes[i] = value[offset, 2].to_u8(16)
      end
    when 32 # Hexstring
      16.times do |i|
        ::UUID.string_has_hex_pair_at! value, i * 2
        @bytes[i] = value[i * 2, 2].to_u8(16)
      end
    when 45 # URN
      raise ArgumentError.new "Invalid URN UUID format, expected string starting with \":urn:uuid:\"." unless value.starts_with? "urn:uuid:"
      [9, 11, 13, 15, 18, 20, 23, 25, 28, 30, 33, 35, 37, 39, 41, 43].each_with_index do |offset, i|
        ::UUID.string_has_hex_pair_at! value, offset
        @bytes[i] = value[offset, 2].to_u8(16)
      end
    else
      raise ArgumentError.new "Invalid string length #{value.size} for UUID, expected 32 (hexstring), 36 (hyphenated) or 46 (urn)."
    end
  end

  def to_s
    slice = to_slice
    String.new(36) do |buffer|
      buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
      slice[0, 4].hexstring(buffer + 0)
      slice[4, 2].hexstring(buffer + 9)
      slice[6, 2].hexstring(buffer + 14)
      slice[8, 2].hexstring(buffer + 19)
      slice[10, 6].hexstring(buffer + 24)
      {36, 36}
    end
  end

  def hexstring
    to_slice.hexstring
  end

  def urn
    String.new(45) do |buffer|
      buffer.copy_from "urn:uuid:".to_unsafe, 9
      (buffer + 9).copy_from to_s.to_unsafe, 36
      {45, 45}
    end
  end

  # Same as `UUID#decode(value : String)`, returns `self`.
  def <<(value : String)
    decode value
    self
  end

  # Same as `UUID#variant=(value : Variant)`, returns `self`.
  def <<(value : Variant)
    variant = value
    self
  end

  # Same as `UUID#version=(value : Version)`, returns `self`.
  def <<(value : Version)
    version = value
    self
  end
end
