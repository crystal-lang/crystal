module Crystal
  module DWARF
    struct Addr
      def initialize(@bytes : Bytes, @address_size : UInt8, @segment_selector_size : UInt8)
      end

      def address_at(offset : Int::Unsigned) : LibC::SizeT
        address = LibC::SizeT.zero
        buf = Bytes.new(pointerof(address).as(UInt8*), sizeof(LibC::SizeT))

        slice = @bytes + (@address_size + @segment_selector_size).to_u32 * offset
        index =
          {% if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian %}
            0
          {% else %}
            sizeof(LibC::SizeT) - @address_size
          {% end %}
        slice[index, @address_size].copy_to(buf)

        address
      end
    end

    def self.each_addr(bytes : Bytes, &)
      reader = Reader.new(bytes)

      until reader.eof?
        unit_length = reader.read_u32
        dwarf64 = unit_length == 0xffffffff
        unit_length = reader.read_u64 if dwarf64
        offset = reader.pos

        version = reader.read_u16
        return unless version == 5

        address_size = reader.read_u8
        segment_selector_size = reader.read_u8

        base = reader.pos
        unit_bytes = reader.read(offset + unit_length - base)

        yield Addr.new(unit_bytes, address_size, segment_selector_size), base
      end
    end

    def self.addr_at?(bytes : Bytes?, addr_base : Int::Unsigned) : Addr?
      return unless bytes

      each_addr(bytes) do |addr, base|
        return addr if base == addr_base
      end
    end
  end
end
