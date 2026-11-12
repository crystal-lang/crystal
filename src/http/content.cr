require "./common"

module HTTP
  # :nodoc:
  module Content
    CONTINUE = "HTTP/1.1 100 Continue\r\n\r\n"

    @continue_sent = false
    setter expects_continue : Bool = false

    def close : Nil
      @expects_continue = false
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

    def read(slice : Bytes) : Int32
      ensure_send_continue
      super
    end

    def read_byte : UInt8?
      ensure_send_continue
      super
    end

    def peek : Bytes?
      ensure_send_continue
      super
    end

    def skip(bytes_count) : Nil
      ensure_send_continue
      super
    end

    def write(slice : Bytes) : NoReturn
      raise IO::Error.new "Can't write to FixedLengthContent"
    end
  end

  # :nodoc:
  class UnknownLengthContent < IO
    include Content

    def initialize(@io : IO)
    end

    def read(slice : Bytes) : Int32
      ensure_send_continue
      @io.read(slice).to_i32
    end

    def read_byte : UInt8?
      ensure_send_continue
      @io.read_byte
    end

    def peek : Bytes?
      ensure_send_continue
      @io.peek
    end

    def skip(bytes_count : Int) : Nil
      ensure_send_continue
      @io.skip(bytes_count)
    end

    def write(slice : Bytes) : NoReturn
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

    # Returns the maximum permitted combined size for the trailing headers.
    #
    # When parsing the trailing headers `ChunkedContent` keeps track of the
    # amount of total bytes consumed for all headers (including line breaks).
    # If the combined byte size of all headers is larger than the permitted size,
    # `IO::Error` is raised.
    #
    # Default: `HTTP::MAX_HEADERS_SIZE`
    getter max_headers_size : Int32

    def initialize(@io : IO, *, @max_headers_size : Int32 = HTTP::MAX_HEADERS_SIZE)
      @chunk_remaining = -1
      @received_final_chunk = false
    end

    def read(slice : Bytes) : Int32
      ensure_send_continue
      count = slice.size
      return 0 if count == 0

      next_chunk

      return 0 if @received_final_chunk

      to_read = Math.min(count, @chunk_remaining)

      bytes_read = @io.read(slice[0, to_read]).to_i32

      if bytes_read == 0
        raise IO::EOFError.new("Invalid HTTP chunked content")
      end

      @chunk_remaining -= bytes_read

      bytes_read
    end

    def read_byte : UInt8?
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

    def peek : Bytes?
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

    def skip(bytes_count : Int) : Nil
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

      chunk_size = read_chunk_size?
      raise IO::Error.new("Invalid HTTP chunked content: invalid chunk line") unless chunk_size

      @chunk_remaining = chunk_size
      if @chunk_remaining == 0
        read_trailer
        @received_final_chunk = true
      end
    end

    # always expect CRLF in chunk framing, reject lone LF
    private def read_crlf
      buf = uninitialized UInt8[2]
      size = @io.read_fully(buf.to_slice)

      unless crlf?(buf.to_slice[0, size])
        raise IO::Error.new("Invalid HTTP chunked content: expected CRLF")
      end
    end

    private def crlf?(bytes)
      bytes.size == 2 &&
        bytes[0] == '\r'.ord &&
        bytes[1] == '\n'.ord
    end

    private def read_chunk_size? : Int32?
      line = @io.read_line(@max_headers_size, chomp: false)

      # chunk-line MUST end with CRLF: https://errata.rfc-editor.org/eid7633/
      # read_line stopped at LF, so rejects lone LF by design
      return unless line.bytesize > 2 && crlf?(line.to_slice[-2, 2])

      bytes = line.to_slice[0...-2]
      chunk_size, digits = read_chunk_size_impl(bytes)
      return unless digits > 0

      bytes += digits
      case bytes.first?
      when nil
        # end-of-line
        chunk_size
      when ' '.ord, '\t'.ord, ';'.ord
        chunk_size if skip_chunk_ext?(bytes)
      else
        # invalid character, includes hexdigits in case of overflow
      end
    end

    private def read_chunk_size_impl(bytes) : {Int32, Int32}
      digits = 0
      chunk_size = 0_u32

      bytes.each do |byte|
        if chunk_size > 0x07ffffff
          # abort: the next digit would overflow, let read_chunk_size validate the rest
          break
        end

        case byte
        when ('0'.ord)..('9'.ord)
          digits += 1
          chunk_size = chunk_size << 4 | (byte &- '0'.ord)
        when ('a'.ord)..('f'.ord)
          digits += 1
          chunk_size = chunk_size << 4 | (10 &+ byte &- 'a'.ord)
        when ('A'.ord)..('F'.ord)
          digits += 1
          chunk_size = chunk_size << 4 | (10 &+ byte &- 'A'.ord)
        else
          break
        end
      end

      {chunk_size.to_i32!, digits}
    end

    private def skip_chunk_ext?(bytes)
      # chunk-ext = *( BWS ";" BWS chunk-ext-name [ BWS "=" BWS chunk-ext-val ] )
      bytes, bws = skip_whitespace(bytes)

      while byte = bytes.first?
        return false unless byte == ';'.ord

        bytes += 1 # consume ';'
        bytes, bws = skip_whitespace(bytes)

        # chunk-ext-name = token
        name = read_token(bytes)
        return false if name.empty?

        bytes += name.size
        bytes, bws = skip_whitespace(bytes)
        break unless byte = bytes.first?
        next unless byte == '='.ord

        bytes += 1 # consume '='
        bytes, bws = skip_whitespace(bytes)
        return false unless byte = bytes.first?

        # chunk-ext-val = token / quoted-string
        if byte == '"'.ord
          value = read_quoted_string(bytes)
          return false unless value
          bytes += value.size + 2
        else
          value = read_token(bytes)
          return false if value.empty?
          bytes += value.size
        end

        bytes, bws = skip_whitespace(bytes)
      end

      !bws
    end

    private def read_token(bytes : Bytes)
      bytes.each_with_index do |byte, index|
        if HTTP::VALID_TOKEN_CHAR_MAP.to_unsafe[byte] == 0
          return index > 0 ? bytes[0, index] : Bytes.empty
        end
      end
      bytes
    end

    private def read_quoted_string(bytes)
      backslash = false
      bytes += 1 # consume opening quote

      bytes.each_with_index do |byte, index|
        case byte
        when '"'.ord
          return bytes[0...index] unless backslash
          backslash = false
        when '\\'.ord
          backslash = !backslash
        when '\t'.ord, (' '.ord)..('~'.ord), 0x80..
          backslash = false
        when '!'.ord, ('#'.ord)..('['.ord), (']'.ord)..('~'.ord)
          return if backslash
        else
          return
        end
      end
    end

    private def skip_whitespace(bytes)
      bws = false

      while byte = bytes.first?
        case byte
        when ' '.ord, '\t'.ord
          bws = true
          bytes += 1
        else
          break
        end
      end

      {bytes, bws}
    end

    private def read_trailer
      max_size = @max_headers_size

      while true
        line = @io.read_line(max_size + 2, chomp: false)

        # always expect CRLF in chunk framing, reject lone LF, reject reached max_size
        break unless line.size >= 2 && crlf?(line.to_slice[-2..])

        # done on empty line (CRLF)
        return if line.bytesize == 2

        max_size -= line.bytesize - 2

        key, value = HTTP.parse_header(line)
        break unless key.present? && headers.add(key, value)
      end

      raise IO::Error.new("Invalid HTTP chunked content: invalid trailer")
    end

    def write(slice : Bytes) : NoReturn
      raise IO::Error.new "Can't write to ChunkedContent"
    end

    def closed? : Bool
      @received_final_chunk || super
    end
  end
end
