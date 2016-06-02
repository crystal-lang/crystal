module UUID
  struct UUID
    include ::UUID::RFC4122

    # Internal representation.
    @data = StaticArray(UInt8, 16).new

    # Generates UUID (RFC 4122 v4).
    def initialize
      initialize RFC4122Version::V4
    end

    # Creates UUID from any 16 `bytes` slice.
    def initialize(bytes : Slice(UInt8))
      raise ArgumentError.new "Invalid bytes length #{bytes.size}, expected 16." if bytes.size != 16
      @data.to_unsafe.copy_from bytes
    end

    # Creates UUID from (optionally hyphenated) string `value`.
    def initialize(value : String)
      case value.size
      when 36 # with hyphens
        [8, 13, 18, 23].each do |offset|
          if value[offset] != '-'
            raise ArgumentError.new "Invalid UUID string format, expected hyphen at char #{offset}."
          end
        end
        [0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34].each_with_index do |offset, i|
          ::UUID.string_has_hex_pair_at! value, offset
          @data[i] = value[offset, 2].to_u8(16)
        end
      when 32 # without hyphens
        16.times do |i|
          ::UUID.string_has_hex_pair_at! value, i * 2
          @data[i] = value[i * 2, 2].to_u8(16)
        end
      else
        raise ArgumentError.new "Invalid string length #{value.size} for UUID, expected 32 (hex) or 36 (hyphenated hex)."
      end
    end

    # Returns 16-byte slice of this UUID.
    def to_slice
      Slice(UInt8).new to_unsafe, 16
    end

    # Returns unsafe pointer to 16-byte slice of this UUID.
    def to_unsafe
      @data.to_unsafe
    end

    # Writes hyphenated string representation for this UUID.
    def to_s(io : IO)
      io << to_s(true)
    end

    # Returns (optionally `hyphenated`) string representation.
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

    # Returns `true` if `other` string represents the same UUID, `false` otherwise.
    def ==(other : String)
      self == UUID.new other
    end

    # Returns `true` if `other` 16-byte slice represents the same UUID, `false` otherwise.
    def ==(other : Slice(UInt8))
      to_slice == other
    end

    # Returns `true` if `other` static 16 bytes represent the same UUID, `false` otherwise.
    def ==(other : StaticArray(UInt8, 16))
      self.==(Slice(UInt8).new other.to_unsafe, 16)
    end
  end
end
