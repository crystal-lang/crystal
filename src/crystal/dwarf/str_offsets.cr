module Crystal
  module DWARF
    struct StrOffsets
      @addresses : Slice(UInt32) | Slice(UInt64)

      def initialize(bytes : Bytes, @dwarf64 : Bool)
        @addresses =
          if @dwarf64
            bytes.unsafe_slice_of(UInt64)
          else
            bytes.unsafe_slice_of(UInt32)
          end
      end

      def [](index : Int::Unsigned) : UInt32 | UInt64
        @addresses[index]
      end
    end

    def self.each_str_offsets(bytes : Bytes, &)
      reader = Reader.new(bytes)

      until reader.eof?
        unit_length = reader.read_u32
        dwarf64 = unit_length == 0xffffffff
        unit_length = reader.read_u64 if dwarf64
        offset = reader.pos

        version = reader.read_u16
        return unless version == 5

        padding = reader.read_u16
        return unless padding == 0

        base = reader.pos
        unit_bytes = reader.read(offset + unit_length - base)

        yield StrOffsets.new(unit_bytes, dwarf64), base
      end
    end

    def self.str_offsets_at?(bytes : Bytes?, str_offsets_base : Int::Unsigned) : StrOffsets?
      return unless bytes

      each_str_offsets(bytes) do |str_offsets, base|
        return str_offsets if base == str_offsets_base
      end
    end
  end
end
