require "secure_random"

module HTTP::Multipart
  class GenerationException < Exception
  end

  # Generates a multipart MIME message.
  #
  # ### Example
  #
  # ```
  # io = MemoryIO.new
  # multipart = HTTP::Multipart::Generator.new(io)
  # multipart.body_part HTTP::Headers{"Content-Type" => "text/plain"}, "hello!"
  # multipart.finish
  # io.to_s # => "----------------------------DTf61dRTHYzprx7rwVQhTWr7\r\nContent-Type: text/plain\r\n\r\nhello!\r\n----------------------------DTf61dRTHYzprx7rwVQhTWr7--"
  # ```
  class Generator
    # Creates a new `Multipart::Generator` which writes the generated multipart
    # message to *io*, using the multipart boundary *boundary*.
    def initialize(@io : IO, @boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
      @state = :START
    end

    getter boundary

    # Finite State Machine diagram: https://gist.github.com/RX14/221c1edfa98d1196711515d4b5c264eb

    # Generates a content type header with multipart subtype *subtype*, and
    # boundary parameter added.
    #
    # ```
    # generator = HTTP::Multipart::Generator.new(io, "a4VF")
    # generator.content_type("mixed") # => "multipart/mixed; boundary=\"a4VF\""
    # ```
    def content_type(subtype = "mixed")
      %(multipart/#{subtype}; boundary="#{boundary.gsub('"', %q[\"])}")
    end

    # Appends *string* to the preamble segment of the multipart message. Throws
    # if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(string : String)
      preamble { |io| string.to_s(io) }
    end

    # Appends *data* to the preamble segment of the multipart message. Throws
    # if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(data : Bytes)
      preamble { |io| io.write data }
    end

    # Appends *preamble_io* to the preamble segment of the multipart message.
    # Throws if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble(preamble_io : IO)
      preamble { |io| IO.copy(preamble_io, io) }
    end

    # Yields an IO that can be used to append to the preamble of the multipart
    # message. Throws if `#body_part` is called before this method.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def preamble
      fail "Cannot generate preamble: body already started" if @state != :START && @state != :PREAMBLE
      yield @io
      @state = :PREAMBLE
    end

    # Appends a body part to the multipart message with the given *headers*
    # and *string*. Throws if `#finish` or `#epilogue` is called before this
    # method.
    def body_part(headers : HTTP::Headers, string : String)
      body_part_impl(headers) { |io| string.to_s(io) }
    end

    # Appends a body part to the multipart message with the given *headers*
    # and *data*. Throws if `#finish` or `#epilogue` is called before this
    # method.
    def body_part(headers : HTTP::Headers, data : Bytes)
      body_part_impl(headers) { |io| io.write data }
    end

    # Appends a body part to the multipart message with the given *headers*
    # and data from *body_io*. Throws if `#finish` or `#epilogue` is called
    # before this method.
    def body_part(headers : HTTP::Headers, body_io : IO)
      body_part_impl(headers) { |io| IO.copy(body_io, io) }
    end

    # Yields an IO that can be used to write to a body part which is appended
    # to the multipart message with the given *headers*. Throws is `#finish` or
    # `#epilogue` is called before this method.
    def body_part(headers : HTTP::Headers)
      body_part_impl(headers) { |io| yield io }
    end

    # Appends a body part to the multipart message with the given *headers*
    # and no body data. Throws is `#finish` or `#epilogue` is called before
    # this method.
    def body_part(headers : HTTP::Headers)
      body_part_impl(headers, empty: true) { }
    end

    private def body_part_impl(headers, empty = false)
      fail "Cannot generate body part: already finished" if @state == :FINISHED
      fail "Cannot generate body part: after epilogue" if @state == :EPILOGUE

      # We don't add a crlf before the first boundary if this is the first body
      # part and there is no preamble
      @io << "\r\n" unless @state == :START
      @io << "--" << @boundary
      headers.each do |name, values|
        values.each do |value|
          @io << "\r\n" << name << ": " << value
        end
      end
      @io << "\r\n\r\n" unless empty

      yield @io

      @state = :BODY_PART
    end

    # Appends *string* to the epilogue segment of the multipart message. Throws
    # if `#finish` is called before this method, or no body parts have been
    # appended.
    #
    # Can be called multiple times to append to the epilogue multiple times.
    def epilogue(string : String)
      epilogue { |io| string.to_s(io) }
    end

    # Appends *data* to the epilogue segment of the multipart message. Throws
    # if `#finish` is called before this method, or no body parts have been
    # appended.
    #
    # Can be called multiple times to append to the epilogue multiple times.
    def epilogue(data : Bytes)
      epilogue { |io| io.write data }
    end

    # Appends *preamble_io* to the epilogue segment of the multipart message.
    # Throws if `#finish` is called before this method, or no body parts have
    # been appended.
    #
    # Can be called multiple times to append to the epilogue multiple times.
    def epilogue(epilogue_io : IO)
      epilogue { |io| IO.copy(epilogue_io, io) }
    end

    # Yields an IO that can be used to append to the epilogue of the multipart
    # message. Throws if `#finish` is called before this method, or no body
    # parts have been appended.
    #
    # Can be called multiple times to append to the preamble multiple times.
    def epilogue
      fail "Cannot generate epilogue: already finished" if @state == :FINISHED
      fail "Cannot generate epilogue: no body parts" if @state == :START || @state == :PREAMBLE

      if @state != :EPILOGUE
        # We need to send the end boundary
        @io << "\r\n--" << @boundary << "--\r\n"
      end

      yield @io

      @state = :EPILOGUE
    end

    # Finalizes the multipart message, this method must be called before the
    # generated multipart message written to the IO is considered valid.
    def finish
      fail "Cannot finish multipart: no body parts" if @state == :START || @state == :PREAMBLE
      fail "Cannot finish multipart: already finished" if @state == :FINISHED

      if @state == :BODY_PART
        # We need to send the end boundary
        @io << "\r\n--" << @boundary << "--"
      end

      @state = :FINISHED
    end

    private def fail(message)
      raise GenerationException.new(message)
    end
  end
end
