require "random/secure"
require "./multipart/*"

# The `HTTP::Multipart` module contains utilities for parsing MIME multipart
# messages, which contain multiple body parts, each containing a header section
# and binary body. The `multipart/form-data` content-type has a separate set of
# utilities in the `HTTP::FormData` module.
module HTTP::Multipart
  # Parses a MIME multipart message, yielding `HTTP::Headers` and an `IO` for
  # each body part.
  #
  # Please note that the IO object yielded to the block is only valid while the
  # block is executing. The IO is closed as soon as the supplied block returns.
  #
  # ```
  # multipart = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # HTTP::Multipart.parse(IO::Memory.new(multipart), "aA40") do |headers, io|
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

  # Extracts the multipart boundary from the Content-Type header. May return
  # `nil` is the boundary was not found.
  #
  # ```
  # HTTP::Multipart.parse_boundary("multipart/mixed; boundary=\"abcde\"") # => "abcde"
  # ```
  def self.parse_boundary(content_type)
    # TODO: remove regex
    match = content_type.match(/\Amultipart\/.*boundary="?([^";,]+)"?/i)
    return nil unless match
    HTTP.dequote_string(match[1])
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
    parse(body, boundary) { |headers, io| yield headers, io }
  end

  # Yields a `Multipart::Builder` to the given block, writing to *io* and
  # using *boundary*. `#finish` is automatically called on the builder.
  def self.build(io, boundary = Multipart.generate_boundary)
    builder = Builder.new(io, boundary)
    yield builder
    builder.finish
  end

  # Yields a `Multipart::Builder` to the given block, returning the generated
  # message as a `String`.
  def self.build(boundary = Multipart.generate_boundary)
    String.build do |io|
      build(io, boundary) { |g| yield g }
    end
  end

  # Returns a unique string suitable for use as a multipart boundary.
  #
  # ```
  # HTTP::Multipart.generate_boundary # => "---------------------------dQu6bXHYb4m5zrRC3xPTGwV"
  # ```
  def self.generate_boundary
    "--------------------------#{Random::Secure.urlsafe_base64(18)}"
  end

  class Error < Exception
  end
end
