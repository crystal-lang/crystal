module Tar
  # Counts written bytes.
  private class CounterWriter
    include IO

    getter count = 0_u64

    def initialize(@io : IO)
    end

    def read(slice : Bytes)
      raise IO::Error.new "can't read from tar entry"
    end

    def write(slice : Bytes)
      @count += slice.size
      @io.write(slice)
    end

    def reset
      @count = 0_u64
    end
  end
end
