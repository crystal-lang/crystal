module HTTP
  # :nodoc:
  abstract class Content
    include IO

    def close
      buffer = uninitialized UInt8[1024]
      while read(buffer.to_slice) > 0
      end
    end
  end

  # :nodoc:
  class FixedLengthContent < Content
    def initialize(@io, size : UInt64)
      @remaining = size
    end

    def read(slice : Slice(UInt8))
      count = Math.min(slice.size.to_u64, @remaining)
      bytes_read = @io.read slice[0, count]
      @remaining -= bytes_read
      bytes_read
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to FixedLengthContent"
    end
  end

  # :nodoc:
  class UnknownLengthContent < Content
    def initialize(@io)
    end

    def read(slice : Slice(UInt8))
      @io.read(slice)
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to UnknownLengthContent"
    end
  end

  # :nodoc:
  class ChunkedContent < Content
    def initialize(@io)
      @chunk_remaining = io.gets.not_nil!.to_i(16)
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
      end

      bytes_read
    end

    private def read_chunk_end
      # Read "\r\n"
      buf = uninitialized UInt8[2]
      @io.read_fully(buf.to_slice)
    end

    def write(slice : Slice(UInt8))
      raise IO::Error.new "Can't write to ChunkedContent"
    end
  end
end
