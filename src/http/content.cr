module HTTP
  # :nodoc:
  module Content
    include IO

    def close
      buffer = uninitialized UInt8[1024]
      while read(buffer.to_slice) > 0
      end
      super
    end
  end

  # :nodoc:
  class FixedLengthContent < IO::Sized
    include Content

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to FixedLengthContent"
    end
  end

  # :nodoc:
  class UnknownLengthContent
    include Content

    def initialize(@io : IO)
    end

    def read(slice : Slice(UInt8))
      @io.read(slice)
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to UnknownLengthContent"
    end
  end

  # :nodoc:
  class ChunkedContent
    include Content
    @chunk_remaining : Int32

    def initialize(@io : IO)
      @chunk_remaining = io.gets.not_nil!.to_i(16)
      check_last_chunk
    end

    def read(slice : Slice(UInt8))
      count = slice.size
      return 0 if @chunk_remaining == 0 || count == 0

      to_read = Math.min(slice.size, @chunk_remaining)

      bytes_read = @io.read slice[0, to_read]
      @chunk_remaining -= bytes_read
      if @chunk_remaining == 0
        read_chunk_end
        @chunk_remaining = @io.gets.not_nil!.to_i(16)
        check_last_chunk
      end

      bytes_read
    end

    private def read_chunk_end
      # Read "\r\n"
      @io.skip(2)
    end

    private def check_last_chunk
      # If we read "0\r\n", we need to read another "\r\n"
      read_chunk_end if @chunk_remaining == 0
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to ChunkedContent"
    end
  end
end
