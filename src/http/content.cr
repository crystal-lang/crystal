require "http/common"

module HTTP
  # :nodoc:
  module Content
    CONTINUE = "HTTP/1.1 100 Continue\r\n\r\n"

    @continue_sent = false
    setter expects_continue : Bool = false

    def close
      @expects_continue = false
      skip_to_end
      super
    end

    protected def ensure_send_continue
      return unless @expects_continue
      return if @continue_sent
      @io << CONTINUE
      @io.flush
      @continue_sent = true
    end
  end

  # :nodoc:
  class FixedLengthContent < IO::Sized
    include Content

    def read(slice : Bytes)
      ensure_send_continue
      super
    end

    def read_byte
      ensure_send_continue
      super
    end

    def peek
      ensure_send_continue
      super
    end

    def skip(bytes_count)
      ensure_send_continue
      super
    end

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
      ensure_send_continue
      @io.read(slice)
    end

    def read_byte
      ensure_send_continue
      @io.read_byte
    end

    def peek
      ensure_send_continue
      @io.peek
    end

    def skip(bytes_count)
      ensure_send_continue
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
      @chunk_remaining = -1
      @received_final_chunk = false
    end

    def read(slice : Bytes)
      ensure_send_continue
      count = slice.size
      return 0 if count == 0

      next_chunk

      return 0 if @received_final_chunk

      to_read = Math.min(count, @chunk_remaining)

      bytes_read = @io.read slice[0, to_read]

      if bytes_read == 0
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end

      @chunk_remaining -= bytes_read

      bytes_read
    end

    def read_byte
      ensure_send_continue
      next_chunk
      return super if @received_final_chunk

      byte = @io.read_byte
      if byte
        @chunk_remaining -= 1
        byte
      else
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end
    end

    def peek
      ensure_send_continue
      next_chunk
      return Bytes.empty if @received_final_chunk

      peek = @io.peek || return

      if @chunk_remaining < peek.size
        peek = peek[0, @chunk_remaining]
      elsif peek.size == 0
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end

      peek
    end

    def skip(bytes_count)
      ensure_send_continue
      if bytes_count <= @chunk_remaining
        @io.skip(bytes_count)
        @chunk_remaining -= bytes_count
      else
        super
      end
    end

    # Checks if the last read consumed a chunk and we
    # need to start consuming the next one.
    private def next_chunk
      return if @chunk_remaining > 0 || @received_final_chunk

      # As soon as we finish reading a chunk we return,
      # in case the following content is delayed (see #3270) and read the chunk
      # delimiter and next chunk start on the next call to `read`.
      read_crlf unless @chunk_remaining == -1 # -1 is the initial value

      @chunk_remaining = read_chunk_size
      if @chunk_remaining == 0
        read_trailer
        @received_final_chunk = true
      end
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

      chunk_size.to_i?(16) || raise IO::Error.new("Invalid HTTP chunked content: invalid chunk size")
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
