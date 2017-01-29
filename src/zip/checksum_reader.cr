module Zip
  # Computes a CRC32 while reading from an underlying IO,
  # optionally verifying the computed value against an
  # expected one.
  private class ChecksumReader
    include IO

    def initialize(@io : IO, @filename : String, verify @expected_crc32 : UInt32? = nil)
      @crc32 = LibC::ULong.new(0)
    end

    def crc32
      @crc32.to_u32
    end

    def read(slice : Bytes)
      read_bytes = @io.read(slice)
      if read_bytes == 0
        if (expected_crc32 = @expected_crc32) && crc32 != expected_crc32
          raise Zip::Error.new("checksum failed for entry #{@filename} (expected #{expected_crc32}, got #{crc32}")
        end
      else
        @crc32 = Zlib.crc32(slice[0, read_bytes], @crc32)
      end
      read_bytes
    end

    def peek
      @io.peek
    end

    def write(slice : Bytes)
      raise IO::Error.new "can't read from Zip::Reader or Zip::File entry"
    end
  end
end
