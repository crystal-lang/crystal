module HTTP
  abstract class Content
    getter pos
    
    def initialize
      @pos = 0
    end
    
    def close
      buffer :: UInt8[1024]
      while read(buffer.to_slice) > 0
      end
    end
  end

  class FixedLengthContent < Content
    include IO

    def initialize(@io, length)
      super()
      @remaining = length
    end

    def read(slice : Slice(UInt8), count)
      count = Math.min(count, @remaining)
      bytes_read = @io.read(slice, count)
      @remaining -= bytes_read
      @pos += bytes_read
      bytes_read
    end

    def write(slice : Slice(UInt8), count)
      raise IO::Error.new "Can't write to FixedLengthContent"
    end
  end

  class ChunkedContent < Content
    include IO

    def initialize(@io)
      super()
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
      @pos += total_read
      total_read
    end

    def write(slice : Slice(UInt8), count)
      raise IO::Error.new "Can't write to ChunkedContent"
    end
  end
  
  class UntilEofContent < Content
    include IO

    def initialize(@io)
      super()
    end
    
    def read(slice : Slice(UInt8), count)
      bytes_read = @io.read(slice, count)
      @pos += bytes_read
      bytes_read
    end
    
    def write(slice : Slice(UInt8), count)
      raise IO::Error.new "Can't write to UntilEofContent"
    end
  end
  
  class EmptyContent < Content
    include IO
    
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
