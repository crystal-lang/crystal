module Zip
  # Counts written bytes and optionally computes a CRC32
  # checksum while writing to an underlying IO.
  private class ChecksumWriter
    include IO

    getter count = 0_u32
    getter crc32 = LibC::ULong.new(0)
    getter! io : IO

    def initialize(@compute_crc32 = false)
    end

    def read(slice : Bytes)
      raise IO::Error.new "can't read from Zip::Writer entry"
    end

    def write(slice : Bytes)
      @count += slice.size
      @crc32 = Zlib.crc32(slice, @crc32) if @compute_crc32
      io.write(slice)
    end

    def io=(@io)
      @count = 0_u32
      @crc32 = LibC::ULong.new(0)
    end
  end
end
