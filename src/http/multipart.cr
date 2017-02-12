module HTTP::Multipart
  # Parses a MIME multipart message, yielding `HTTP::Headers` and an `IO` for
  # each body part.
  #
  # Please note that the IO object yielded to the block is only valid while the
  # block is executing. The IO is closed as soon as the supplied block returns.
  #
  # ```
  # multipart = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # HTTP::Multipart.parse(MemoryIO.new(multipart), "aA40") do |headers, io|
  #   headers["Content-Type"] # => "text/plain"
  #   io.gets_to_end          # => "body"
  # end
  # ```
  #
  # See: `Multipart::Parser`
  def self.parse(io, boundary)
    parser = Parser.new(io, boundary)
    while parser.has_next?
      parser.next { |headers, io| yield headers, io }
    end
  end

  # Parses the multipart boundary from the value of the Content-Type header,
  # or nil if the boundary was not found.
  #
  # ```
  # HTTP::Multipart.parse_boundary("multipart/mixed; boundary=\"abcde\"") # => "abcde"
  # ```
  def self.parse_boundary(content_type)
    # TODO: optimise and handle escapes in quoted strings
    match = content_type.match(/\Amultipart\/.*boundary="?([^";,]+)"?/i)
    return nil unless match
    match[1]
  end

  # Parses a MIME multipart message, yielding `HTTP::Headers` and an `IO` for
  # each body part.
  #
  # Please note that the IO object yielded to the block is only valid while the
  # block is executing. The IO is closed as soon as the supplied block returns.
  #
  # ```
  # headers = HTTP::Headers{"Content-Type" => "multipart/mixed; boundary=aA40"}
  # body = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # request = HTTP::Request.new("POST", "/", headers, body)
  #
  # HTTP::Multipart.parse(request) do |headers, io|
  #   headers["Content-Type"] # => "text/plain"
  #   io.gets_to_end          # => "body"
  # end
  # ```
  #
  # See: `Multipart::Parser`
  def self.parse(request : HTTP::Request)
    boundary = parse_boundary(request.headers["Content-Type"])
    return nil unless boundary

    body = request.body
    return nil unless body
    parse(MemoryIO.new(body), boundary) { |headers, io| yield headers, io }
  end

  # Yields a `Multipart::Generator` to the given block, writing to *io* and
  # using *boundary*.
  def self.generate(io, boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
    generator = Generator.new(io, boundary)
    yield generator
    generator.finish
  end

  # Yields a `Multipart::Generator` to the given block, returning the generated
  # message as a `String`.
  def self.generate(boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
    String.build do |io|
      generate(io, boundary) { |g| yield g }
    end
  end
end
