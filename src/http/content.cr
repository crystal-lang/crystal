module HTTP
  abstract class Content
    def close
      buffer :: UInt8[1024]
      while read(buffer.to_slice) > 0
      end
    end
  end

  class FixedLengthContent < Content
    include IO

    def initialize(@io, length)
      @remaining = length
    end

    def read(slice : Slice(UInt8), count)
      count = Math.min(count, @remaining)
      bytes_read = @io.read(slice, count)
      @remaining -= bytes_read
      bytes_read
    end

    def write(slice : Slice(UInt8), count)
      raise IO::Error.new "Can't write to FixedLengthContent"
    end
  end

  class ChunkedContent < Content
    include IO

    def initialize(@io)
      @chunk_remaining = io.gets.not_nil!.to_i(16)
    end

    def read(slice : Slice(UInt8), count)
      total_read = 0
      while @chunk_remaining > 0 && count > 0
        to_read = Math.min(count, @chunk_remaining)
        bytes_read = @io.read(slice, to_read)
        slice += bytes_read
        total_read += bytes_read
        count -= bytes_read
        @chunk_remaining -= bytes_read
        if @chunk_remaining == 0
          @io.read(2) # Read \r\n
          @chunk_remaining = @io.gets.not_nil!.to_i(16)

          if @chunk_remaining == 0
            @io.read(2) # Read \r\n
            break
          end
        end
      end
      total_read
    end

    def write(slice : Slice(UInt8), count)
      raise IO::Error.new "Can't write to ChunkedContent"
    end
  end
  
  class EmptyContent < Content
    include IO

    def initialize
    end
    
    def read(slice : Slice(UInt8), count)
      0
    end
    
    def write(slice : Slice(UInt8), count)
      raise IO::Error.new "Can't write to EmptyContent"
    end
    
    def close
    end
  end
end
