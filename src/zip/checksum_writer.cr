module Zip
  # Counts written bytes and optionally computes a CRC32
  # checksum while writing to an underlying IO.
  private class ChecksumWriter
    include IO

    getter count = 0_u32
    getter crc32 = CRC32.initial
    getter! io : IO

    def initialize(@compute_crc32 = false)
    end

    def read(slice : Bytes)
      raise IO::Error.new "Can't read from Zip::Writer entry"
    end

    def write(slice : Bytes)
      @count += slice.size
      @crc32 = CRC32.update(slice, @crc32) if @compute_crc32
      io.write(slice)
    end

    def io=(@io)
      @count = 0_u32
      @crc32 = CRC32.initial
    end
  end
end
