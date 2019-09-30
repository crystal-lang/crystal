module Zip
  # Computes the CRC32 checksum of bytes being written into it. Best used
  # in combination with an IO::MultiWriter
  class CRC32Writer < IO
    def initialize
      @crc32 = CRC32.initial
    end

    def read(slice : Bytes)
      raise IO::Error.new "Can't read from Zip::Writer entry"
    end

    def write(slice : Bytes)
      return if slice.empty?
      @crc32 = CRC32.update(slice, @crc32)
    end

    def to_u32
      @crc32.to_u32
    end
  end
end
