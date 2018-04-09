require "http/common"

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
  class UnknownLengthContent < IO
    include Content

    def initialize(@io : IO)
    end

    def read(slice : Bytes)
      @io.read(slice)
    end

    def read_byte
      @io.read_byte
    end

    def peek
      @io.peek
    end

    def skip(bytes_count)
      @io.skip(bytes_count)
    end

    def write(slice : Bytes)
      raise IO::Error.new "Can't write to UnknownLengthContent"
    end
  end

  # :nodoc:
  class ChunkedContent < IO
    include Content

    # Returns trailing headers read by this chunked content.
    #
    # The value will only be populated once the entire content has been read,
    # i.e. this IO is at EOF.
    #
    # All headers in the trailing headers section will be returned. Applications
    # need to make sure to ignore them or fail if headers are not allowed
    # in the chunked trailer part (see [RFC 7230 section 4.1.2](https://tools.ietf.org/html/rfc7230#section-4.1.2)).
    getter headers : HTTP::Headers { HTTP::Headers.new }

    def initialize(@io : IO)
      @chunk_remaining = 0
      @expect_chunk_start = true
    end

    def read(slice : Bytes)
      count = slice.size
      return 0 if count == 0

      next_chunk

      return 0 if @chunk_remaining == 0

      to_read = Math.min(count, @chunk_remaining)

      bytes_read = @io.read slice[0, to_read]

      if bytes_read == 0
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end

      chunk_bytes_read bytes_read

      bytes_read
    end

    def read_byte
      next_chunk
      return super if @chunk_remaining == 0

      byte = @io.read_byte
      if byte
        chunk_bytes_read 1
        byte
      else
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end
    end

    def peek
      next_chunk
      return nil if @chunk_remaining == 0

      peek = @io.peek || return

      if @chunk_remaining < peek.size
        peek = peek[0, @chunk_remaining]
      elsif peek.size == 0
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end

      peek
    end

    def skip(bytes_count)
      if bytes_count <= @chunk_remaining
        @io.skip(bytes_count)
        chunk_bytes_read bytes_count
      else
        super
      end
    end

    private def chunk_bytes_read(size)
      @chunk_remaining -= size

      # As soon as we finish reading a chunk we return,
      # in case the next content is delayed (see #3270).
      # We set @expect_chunk_start to true so we read the next
      # chunk start on the next call to `read`.
      if @chunk_remaining == 0
        read_crlf
        @expect_chunk_start = true
      end
    end

    # Check if the last read consumed a chunk and we
    # need to start consuming the next one.
    private def next_chunk
      return unless @expect_chunk_start

      if read_chunk_size == 0
        read_trailer
      end

      @expect_chunk_start = false
    end

    private def read_crlf
      char = @io.read_char
      if char == '\r'
        char = @io.read_char
      end
      if char != '\n'
        raise IO::Error.new("Invalid HTTP chunked content: expected CRLF")
      end
    end

    private def read_chunk_size
      line = @io.read_line(HTTP::MAX_HEADER_SIZE, chomp: true)

      if index = line.byte_index(';'.ord)
        chunk_size = line.byte_slice(0, index)
      else
        chunk_size = line
      end

      @chunk_remaining = chunk_size.to_i?(16) || raise IO::Error.new("Invalid HTTP chunked content: invalid chunk size")
    end

    private def read_trailer
      while true
        line = @io.read_line(HTTP::MAX_HEADER_SIZE, chomp: true)
        break if line.empty?

        key, value = HTTP.parse_header(line)
        break unless headers.add?(key, value)
      end
    end

    def write(slice : Bytes)
      raise IO::Error.new "Can't write to ChunkedContent"
    end
  end
end
