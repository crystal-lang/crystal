module Compress::Zip
  # Counts written bytes. Intended to be used with IO::MultiWriter as one of the outputs
  class OutputCounter < IO
    getter bytes_written = 0_u64

    def read(slice : Bytes)
      raise IO::Error.new "Can't read from Zip::OutputCounter entry"
    end

    def write(slice : Bytes) : Nil
      return if slice.empty?
      @bytes_written += slice.size
      nil
    end

    def simulate_write(by : Int)
      @bytes_written += by
    end

    def to_u64
      @bytes_written
    end
  end
end
