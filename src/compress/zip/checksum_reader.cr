module Compress::Zip
  # Computes a CRC32 while reading from an underlying IO,
  # optionally verifying the computed value against an
  # expected one.
  private class ChecksumReader < IO
    getter crc32 = ::Digest::CRC32.initial

    def initialize(@io : IO, @filename : String, verify @expected_crc32 : UInt32? = nil)
    end

    def read(slice : Bytes) : Int32
      read_bytes = @io.read(slice)
      if read_bytes == 0
        if (expected_crc32 = @expected_crc32) && crc32 != expected_crc32
          raise Compress::Zip::Error.new("Checksum failed for entry #{@filename} (expected #{expected_crc32}, got #{crc32}")
        end
      else
        @crc32 = ::Digest::CRC32.update(slice[0, read_bytes], @crc32)
      end
      read_bytes
    end

    def peek : Bytes?
      @io.peek
    end

    def write(slice : Bytes) : NoReturn
      raise IO::Error.new "Can't write to Zip::Reader or Zip::File entry"
    end
  end
end
