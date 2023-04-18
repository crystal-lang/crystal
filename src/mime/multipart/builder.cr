module MIME::Multipart
  # Builds a multipart MIME message.
  #
  # ### Example
  #
  # ```
  # require "mime/multipart"
  #
  # io = IO::Memory.new # This is a stub. Actually, any IO can be used.
  # multipart = MIME::Multipart::Builder.new(io)
  # multipart.body_part HTTP::Headers{"Content-Type" => "text/plain"}, "hello!"
  # multipart.finish
  # io.to_s # => "----------------------------DTf61dRTHYzprx7rwVQhTWr7\r\nContent-Type: text/plain\r\n\r\nhello!\r\n----------------------------DTf61dRTHYzprx7rwVQhTWr7--"
  # ```
  class Builder
    # Creates a new `Multipart::Builder` which writes the generated multipart
    # message to *io*, using the multipart boundary *boundary*.
    def initialize(@io : IO, @boundary = Multipart.generate_boundary)
      @state = State::START
    end

    getter boundary

    # Finite State Machine diagram: https://gist.github.com/RX14/221c1edfa98d1196711515d4b5c264eb

    # Returns a content type header with multipart subtype *subtype*, and
    # boundary parameter added.
    #
    # ```
    # require "mime/multipart"
    #
    # io = IO::Memory.new # This is a stub. Actually, any IO can be used.
    # builder = MIME::Multipart::Builder.new(io, "a4VF")
    # builder.content_type("mixed") # => "multipart/mixed; boundary=a4VF"
    # ```
    def content_type(subtype = "mixed") : String
      MIME::MediaType.new("multipart/#{subtype}", {"boundary" => @boundary}).to_s
    end

    # Appends *string* to the preamble segment of the multipart message. Throws
    # if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(string : String) : Nil
      preamble { |io| string.to_s(io) }
    end

    # Appends *data* to the preamble segment of the multipart message. Throws
    # if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(data : Bytes) : Nil
      preamble(&.write(data))
    end

    # Appends *preamble_io* to the preamble segment of the multipart message.
    # Throws if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(preamble_io : IO) : Nil
      preamble { |io| IO.copy(preamble_io, io) }
    end

    # Yields an IO that can be used to append to the preamble of the multipart
    # message. Throws if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(&)
      fail "Cannot generate preamble: body already started" unless @state.start? || @state.preamble?
      yield @io
      @state = State::PREAMBLE
    end

    # Appends a body part to the multipart message with the given *headers*
    # and *string*. Throws if `#finish` or `#epilogue` is called before this
    # method.
    def body_part(headers : HTTP::Headers, string : String) : Nil
      body_part_impl(headers) { |io| string.to_s(io) }
    end

    # Appends a body part to the multipart message with the given *headers*
    # and *data*. Throws if `#finish` or `#epilogue` is called before this
    # method.
    def body_part(headers : HTTP::Headers, data : Bytes) : Nil
      body_part_impl(headers, &.write(data))
    end

    # Appends a body part to the multipart message with the given *headers*
    # and data from *body_io*. Throws if `#finish` or `#epilogue` is called
    # before this method.
    def body_part(headers : HTTP::Headers, body_io : IO) : Nil
      body_part_impl(headers) { |io| IO.copy(body_io, io) }
    end

    # Yields an IO that can be used to write to a body part which is appended
    # to the multipart message with the given *headers*. Throws if `#finish` or
    # `#epilogue` is called before this method.
    def body_part(headers : HTTP::Headers, &)
      body_part_impl(headers) { |io| yield io }
    end

    # Appends a body part to the multipart message with the given *headers*
    # and no body data. Throws is `#finish` or `#epilogue` is called before
    # this method.
    def body_part(headers : HTTP::Headers) : Nil
      body_part_impl(headers, empty: true) { }
    end

    private def body_part_impl(headers, empty = false, &)
      fail "Cannot generate body part: already finished" if @state.finished?
      fail "Cannot generate body part: after epilogue" if @state.epilogue?

      # We don't add a crlf before the first boundary if this is the first body
      # part and there is no preamble
      @io << "\r\n" unless @state.start?
      @io << "--" << @boundary
      headers.each do |name, values|
        values.each do |value|
          @io << "\r\n" << name << ": " << value
        end
      end
      @io << "\r\n\r\n" unless empty

      yield @io

      @state = State::BODY_PART
    end

    # Appends *string* to the epilogue segment of the multipart message. Throws
    # if `#finish` is called before this method, or no body parts have been
    # appended.
    #
    # Can be called multiple times to append to the epilogue multiple times.
    def epilogue(string : String) : Nil
      epilogue { |io| string.to_s(io) }
    end

    # Appends *data* to the epilogue segment of the multipart message. Throws
    # if `#finish` is called before this method, or no body parts have been
    # appended.
    #
    # Can be called multiple times to append to the epilogue multiple times.
    def epilogue(data : Bytes) : Nil
      epilogue(&.write(data))
    end

    # Appends *preamble_io* to the epilogue segment of the multipart message.
    # Throws if `#finish` is called before this method, or no body parts have
    # been appended.
    #
    # Can be called multiple times to append to the epilogue multiple times.
    def epilogue(epilogue_io : IO) : Nil
      epilogue { |io| IO.copy(epilogue_io, io) }
    end

    # Yields an IO that can be used to append to the epilogue of the multipart
    # message. Throws if `#finish` is called before this method, or no body
    # parts have been appended.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def epilogue(&)
      case @state
      in .start?, .preamble?
        fail "Cannot generate epilogue: no body parts"
      in .finished?
        fail "Cannot generate epilogue: already finished"
      in .epilogue?
        # do nothing
      in .body_part?
        # We need to send the end boundary
        @io << "\r\n--" << @boundary << "--\r\n"
      in .errored?
        fail "BUG: unexpected error state"
      end

      yield @io

      @state = State::EPILOGUE
    end

    # Finalizes the multipart message, this method must be called to properly
    # end the multipart message.
    def finish : Nil
      case @state
      in .start?, .preamble?
        fail "Cannot finish multipart: no body parts"
      in .finished?
        fail "Cannot finish multipart: already finished"
      in .body_part?
        # We need to send the end boundary
        @io << "\r\n--" << @boundary << "--"
      in .epilogue?
        # do nothing
      in .errored?
        fail "BUG: unexpected error state"
      end

      @state = State::FINISHED
      @io.flush
    end

    private def fail(msg)
      raise Multipart::Error.new msg
    end
  end
end
