module HTTP::FormData
  class GenerationException < Exception
  end

  # Generates a multipart/form-data message.
  #
  # ### Example
  #
  # ```
  # io = MemoryIO.new
  # generator = HTTP::FormData::Generator.new(io, "aA47")
  # generator.field("name", "joe")
  # file = MemoryIO.new "file contents"
  # generator.file("upload", io, FileMetadata.new(filename: "test.txt"))
  # generator.finish
  # io.to_s # => "--aA47\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\njoe\r\n--aA47\r\nContent-Disposition: form-data; name=\"upload\"; filename=\"test.txt\"\r\n\r\nfile contents\r\n--aA47--"
  # ```
  class Generator
    # Creates a new `FormData::Generator` which writes to *io*, using the
    # multipart boundary *boundary*.
    def initialize(@io : IO, @boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
      @state = :START
    end

    getter boundary

    # Generates a content type header with correct boundary parameter.
    #
    # ```
    # generator = HTTP::FormData::Generator.new(io, "a4VF")
    # generator.content_type # => "multipart/form-data; boundary=\"a4VF\""
    # ```
    def content_type
      %(multipart/form-data; boundary="#{boundary.gsub('"', %q[\"])}")
    end

    # Adds a form part with the given *name* and *value*. *Headers* can
    # optionally be provided for the form part.
    def field(name, value, headers : HTTP::Headers = HTTP::Headers.new)
      file(name, MemoryIO.new(value), headers: headers)
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
        io << %(form-data; name=")
        io << name.gsub('"', %q(\"))
        io << '"'

        if filename = metadata.filename
          io << %(; filename=")
          io << filename.gsub('"', %q(\"))
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
      raise GenerationException.new(msg)
    end
  end
end
