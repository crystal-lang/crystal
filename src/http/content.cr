module HTTP
  # :nodoc:
  module Content
    def close
      skip_to_end
      super
    end
  end

  # :nodoc:
  class FixedLengthContent < IO::Sized
    include Content

    def write(slice : Bytes)
      raise IO::Error.new "Can't write to FixedLengthContent"
    end
  end

  # :nodoc:
  class UnknownLengthContent
    include IO
    include Content

    def initialize(@io : IO)
    end

    def read(slice : Bytes)
      @io.read(slice)
    end

    def read_byte
      @io.read_byte
    end

    def gets(delimiter : Char, limit : Int, chomp = false) : String?
      return super if @encoding

      @io.gets(delimiter, limit, chomp)
    end

    def skip(bytes_count)
      @io.skip(bytes_count)
    end

    def write(slice : Bytes)
      raise IO::Error.new "Can't write to UnknownLengthContent"
    end
  end

  # :nodoc:
  class ChunkedContent
    include IO
    include Content
    @chunk_remaining : Int32

    def initialize(@io : IO)
      @chunk_remaining = io.gets.not_nil!.to_i(16)
      @read_chunk_start = false
      check_last_chunk
    end

    def read(slice : Bytes)
      count = slice.size
      return 0 if count == 0

      # Check if the last read consumed a chunk and we
      # need to start consuming the next one.
      if @read_chunk_start
        read_chunk_end
        @chunk_remaining = @io.gets.not_nil!.to_i(16)
        check_last_chunk
        @read_chunk_start = false
      end

      return 0 if @chunk_remaining == 0

      to_read = Math.min(slice.size, @chunk_remaining)

      bytes_read = @io.read slice[0, to_read]
      @chunk_remaining -= bytes_read

      check_chunk_remaining_is_zero

      bytes_read
    end

    def read_byte
      if @chunk_remaining > 0
        byte = @io.read_byte
        if byte
          @chunk_remaining -= 1
          check_chunk_remaining_is_zero
        end
        byte
      else
        super
      end
    end

    def skip(bytes_count)
      if bytes_count <= @chunk_remaining
        @io.skip(bytes_count)
        @chunk_remaining -= bytes_count
        check_chunk_remaining_is_zero
      else
        super
      end
    end

    private def check_chunk_remaining_is_zero
      # As soon as we finish reading a chunk we return,
      # in case the next content is delayed (see #3270).
      # We set @read_chunk_start to true so we read the next
      # chunk start on the next call to `read`.
      if @chunk_remaining == 0
        @read_chunk_start = true
      end
    end

    private def read_chunk_end
      # Read "\r\n"
      @io.skip(2)
    end

    private def check_last_chunk
      # If we read "0\r\n", we need to read another "\r\n"
      read_chunk_end if @chunk_remaining == 0
    end

    def write(slice : Bytes)
      raise IO::Error.new "Can't write to ChunkedContent"
    end
  end
end
