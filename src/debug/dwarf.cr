require "./dwarf/abbrev"
require "./dwarf/info"
require "./dwarf/line_numbers"
require "./dwarf/strings"

module Debug
  module DWARF
    def self.read_unsigned_leb128(io : IO)
      result = 0_u32
      shift = 0

      loop do
        byte = io.read_byte.not_nil!.to_i
        result |= (byte & 0x7f) << shift
        break if byte.bit(7) == 0
        shift += 7
      end

      result
    end

    def self.read_signed_leb128(io : IO)
      result = 0_i32
      shift = 0
      size = 32
      byte = 0_u8

      loop do
        byte = io.read_byte.not_nil!.to_i
        result |= (byte & 0x7f) << shift
        shift += 7
        break if byte.bit(7) == 0
      end

      # sign bit of byte is 2nd high order bit (0x40)
      if (shift < size) && (byte.bit(6) == 1)
        # sign extend
        result |= -(1 << shift)
      end

      result
    end
  end
end
