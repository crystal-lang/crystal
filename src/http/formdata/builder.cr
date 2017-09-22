module HTTP::FormData
  # Builds a multipart/form-data message.
  #
  # ### Example
  #
  # ```
  # io = IO::Memory.new
  # builder = HTTP::FormData::Builder.new(io, "aA47")
  # builder.field("name", "joe")
  # file = IO::Memory.new("file contents")
  # builder.file("upload", file, FileMetadata.new(filename: "test.txt"))
  # builder.finish
  # io.to_s # => "--aA47\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\njoe\r\n--aA47\r\nContent-Disposition: form-data; name=\"upload\"; filename=\"test.txt\"\r\n\r\nfile contents\r\n--aA47--"
  # ```
  class Builder
    # Creates a new `FormData::Builder` which writes to *io*, using the
    # multipart boundary *boundary*.
    def initialize(@io : IO, @boundary = Multipart.generate_boundary)
      @state = :START
    end

    getter boundary

    # Returns a content type header with correct boundary parameter.
    #
    # ```
    # builder = HTTP::FormData::Builder.new(io, "a4VF")
    # builder.content_type # => "multipart/form-data; boundary=\"a4VF\""
    # ```
    def content_type
      String.build do |str|
        str << "multipart/form-data; boundary=\""
        HTTP.quote_string(@boundary, str)
        str << '"'
      end
    end

    # Adds a form part with the given *name* and *value*. *Headers* can
    # optionally be provided for the form part.
    def field(name, value, headers : HTTP::Headers = HTTP::Headers.new)
      file(name, IO::Memory.new(value), headers: headers)
    end

    # Adds a form part called *name*, with data from *io* as the value.
    # *Metadata* can be provided to add extra metadata about the file to the
    # Content-Disposition header for the form part. Other headers can be added
    # using *headers*.
    def file(name, io, metadata : FileMetadata = FileMetadata.new, headers : HTTP::Headers = HTTP::Headers.new)
      fail "Cannot add form part: already finished" if @state == :FINISHED

      headers["Content-Disposition"] = generate_content_disposition(name, metadata)

      # We don't add a crlf before the first boundary if this is the first body part.
      @io << "\r\n" unless @state == :START
      @io << "--" << @boundary
      headers.each do |name, values|
        values.each do |value|
          @io << "\r\n" << name << ": " << value
        end
      end
      @io << "\r\n\r\n"
      IO.copy(io, @io)

      @state = :FIELD
    end

    # Finalizes the multipart message, this method must be called before the
    # generated multipart message written to the IO is considered valid.
    def finish
      fail "Cannot finish form-data: no body parts" if @state == :START
      fail "Cannot finish form-data: already finished" if @state == :FINISHED

      @io << "\r\n--" << @boundary << "--"

      @state = :FINISHED
    end

    private def generate_content_disposition(name, metadata)
      String.build do |io|
        io << "form-data; name=\""
        HTTP.quote_string(name, io)
        io << '"'

        if filename = metadata.filename
          io << "; filename=\""
          HTTP.quote_string(filename, io)
          io << '"'
        end

        if creation_time = metadata.creation_time
          io << %(; creation-date=")
          creation_time.to_s("%a, %d %b %Y %H:%M:%S %z", io)
          io << '"'
        end

        if modification_time = metadata.modification_time
          io << %(; modification-date=")
          modification_time.to_s("%a, %d %b %Y %H:%M:%S %z", io)
          io << '"'
        end

        if read_time = metadata.read_time
          io << %(; read-date=")
          read_time.to_s("%a, %d %b %Y %H:%M:%S %z", io)
          io << '"'
        end

        if size = metadata.size
          io << %(; size=) << size
        end
      end
    end

    private def fail(msg)
      raise FormData::Error.new(msg)
    end
  end
end
