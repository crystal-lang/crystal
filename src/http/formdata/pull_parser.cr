module HTTP::FormData
  class ParseException < Exception
  end

  # Parses a multipart/form-data message. Callbacks are used to process files
  # and fields.
  #
  # ### Example
  #
  # ```
  # form_data = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nfield data\r\n--aA40--"
  # parser = HTTP::FormData::Parser.new(MemoryIO.new(form_data), "aA40")
  #
  # parser.field("field1") do |data|
  #   data # => "field data"
  # end
  #
  # parser.run
  # ```
  class PullParser
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
    # parser = HTTP::FormData::Parser.new(MemoryIO.new(form_data), "aA40")
    # parser.next do |field, io, meta, headers|
    #   field                   # => "field1"
    #   io.gets_to_end          # => "field data"
    #   meta.filename           # => "foo.txt"
    #   meta.size               # => 13
    #   headers["Content-Type"] # => "text/plain"
    # end
    # ```
    def next
      raise ParseException.new("Parser has already finished parsing") unless has_next?

      while @multipart.has_next?
        @multipart.next do |headers, io|
          content_disposition = headers.get?("Content-Disposition").try &.[0]
          break unless content_disposition

          field_name, metadata = FormData.parse_content_disposition content_disposition

          yield field_name, io, metadata, headers
        end
      end
    end

    # True if `#next` can be called legally.
    def has_next?
      @multipart.has_next?
    end
  end
end
