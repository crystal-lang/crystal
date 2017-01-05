module HTTP::FormData
  class Parser
    # Create a new parser which parses *io* with multipart boundary *boundary*.
    def initialize(io, boundary)
      @multipart = Multipart::Parser.new(io, boundary)
    end

    # Parses the next form-data part and yields field name, io, `FileMetadata`,
    # and raw headers.
    #
    # This method yields once instead of returning the values, because the IO
    # object yielded to the block is only valid while the block is executing.
    # The IO object will be closed as soon as the block returns. To store the
    # content of the body part for longer than the block, the IO must be read
    # into memory.
    #
    # ```
    # form_data = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"; filename=\"foo.txt\"; size=13\r\nContent-Type: text/plain\r\n\r\nfield data\r\n--aA40--"
    # parser = HTTP::FormData::Parser.new(IO::Memory.new(form_data), "aA40")
    # parser.next do |part|
    #   part.name                    # => "field1"
    #   part.io.gets_to_end          # => "field data"
    #   part.filename                # => "foo.txt"
    #   part.size                    # => 13
    #   part.headers["Content-Type"] # => "text/plain"
    # end
    # ```
    def next
      raise FormData::Error.new("Parser has already finished parsing") unless has_next?

      while @multipart.has_next?
        @multipart.next do |headers, io|
          yield HTTP::FormData::Part.new(headers, io)
        end
      end
    end

    # True if `#next` can be called legally.
    def has_next?
      @multipart.has_next?
    end
  end
end
