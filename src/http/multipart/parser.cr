module HTTP::Multipart
  class ParseException < Exception
  end

  # Parses multipart MIME messages.
  #
  # ### Example
  #
  # ```
  # multipart = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # parser = HTTP::Multipart::Parser.new(MemoryIO.new(multipart), "aA40")
  #
  # while parser.has_next?
  #   parser.next do |headers, io|
  #     headers["Content-Type"] # => "text/plain"
  #     io.gets_to_end          # => "body"
  #   end
  # end
  # ```
  #
  # Please note that the IO object yielded by `#next` is only valid until the
  # block returns.
  class Parser
    # Creates a new `Multipart::Parser` which parses *io* with multipart
    # boundary *boundary*.
    def initialize(@io : IO, @boundary : String)
      @state = :PREAMBLE
      @dash_boundary = "--#{@boundary}"
      @delimiter = "\r\n#{@dash_boundary}"
    end

    # Parses the next body part and yields headers as `HTTP::Headers` and the
    # body text as an `IO`.
    #
    # This method yields once instead of returning the values, because the IO
    # object yielded to the block is only valid while the block is executing.
    # The IO object will be closed as soon as the block returns. To store the
    # content of the body part for longer than the block, the IO must be read
    # into memory.
    #
    # ```
    # multipart = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
    # parser = HTTP::Multipart::Parser.new(MemoryIO.new(multipart), "aA40")
    # parser.next do |headers, io|
    #   headers["Content-Type"] # => "text/plain"
    #   io.gets_to_end          # => "body"
    # end
    # ```
    def next
      raise ParseException.new "Multipart parser already finished parsing" if @state == :FINISHED
      raise ParseException.new "Multipart parser is in an errored state" if @state == :ERRORED

      if @state == :PREAMBLE
        preamble_io = IO::Delimited.new(@io, read_delimiter: @dash_boundary)

        # Discard preamble
        buffer = uninitialized UInt8[1024]
        while preamble_io.read(buffer.to_slice) > 0
        end

        fail if close_delimiter?
        @state = :PART_START
      end

      if @state == :PART_START
        body_io = IO::Delimited.new(@io, read_delimiter: @delimiter)
        headers = parse_headers(body_io)

        begin
          yield headers, body_io
        ensure
          # Read to end of body
          buffer2 = uninitialized UInt8[1024]
          while body_io.read(buffer2.to_slice) > 0
          end

          body_io.close

          @state = :FINISHED if close_delimiter?
        end
      end
    rescue ex
      @state = :ERRORED
      raise ex
    end

    # True if `#next` can be called legally.
    def has_next?
      @state != :FINISHED && @state != :ERRORED
    end

    private def parse_headers(io)
      headers = HTTP::Headers.new

      while line = io.gets
        if line == "\r\n"
          # Finished parsing
          return headers
        end

        name, value = HTTP.parse_header(line)
        headers.add(name, value)
      end

      headers
    end

    # This method is used directly after reading a boundary, to determine if
    # it's a close delimiter or not.
    #
    # If it's not a close delimiter, it eats the transport padding and crlf
    # after a delimiter.
    private def close_delimiter?
      transport_padding_crlf = @io.gets("\r\n")
      fail unless transport_padding_crlf

      if transport_padding_crlf != "\r\n"
        return true if transport_padding_crlf.starts_with?("--")

        fail unless transport_padding_crlf.ends_with?("\r\n")
        fail unless transport_padding_crlf[0..-2].chars.all? { |chr| chr == ' ' || chr == '\t' }
      end

      false
    end

    private def fail
      raise ParseException.new "Invalid multipart message"
    end
  end
end
