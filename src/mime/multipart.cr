require "random/secure"
require "./multipart/*"
require "mime/media_type"

# The `MIME::Multipart` module contains utilities for parsing MIME multipart
# messages, which contain multiple body parts, each containing a header section
# and binary body. The `multipart/form-data` content-type has a separate set of
# utilities in the `HTTP::FormData` module.
module MIME::Multipart
  # Parses a MIME multipart message, yielding `HTTP::Headers` and an `IO` for
  # each body part.
  #
  # Please note that the IO object yielded to the block is only valid while the
  # block is executing. The IO is closed as soon as the supplied block returns.
  #
  # ```
  # require "mime/multipart"
  #
  # multipart = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # MIME::Multipart.parse(IO::Memory.new(multipart), "aA40") do |headers, io|
  #   headers["Content-Type"] # => "text/plain"
  #   io.gets_to_end          # => "body"
  # end
  # ```
  #
  # See: `Multipart::Parser`
  def self.parse(io, boundary, &)
    parser = Parser.new(io, boundary)
    while parser.has_next?
      parser.next { |headers, io| yield headers, io }
    end
  end

  # Extracts the multipart boundary from the Content-Type header. May return
  # `nil` is the boundary was not found.
  #
  # ```
  # require "mime/multipart"
  #
  # MIME::Multipart.parse_boundary("multipart/mixed; boundary=\"abcde\"") # => "abcde"
  # ```
  def self.parse_boundary(content_type) : String?
    type = MIME::MediaType.parse?(content_type)

    if type && type.type == "multipart"
      type["boundary"]?.presence
    end
  end

  # Parses a MIME multipart message, yielding `HTTP::Headers` and an `IO` for
  # each body part.
  #
  # Please note that the IO object yielded to the block is only valid while the
  # block is executing. The IO is closed as soon as the supplied block returns.
  #
  # ```
  # require "http"
  # require "mime/multipart"
  #
  # headers = HTTP::Headers{"Content-Type" => "multipart/mixed; boundary=aA40"}
  # body = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # request = HTTP::Request.new("POST", "/", headers, body)
  #
  # MIME::Multipart.parse(request) do |headers, io|
  #   headers["Content-Type"] # => "text/plain"
  #   io.gets_to_end          # => "body"
  # end
  # ```
  #
  # See: `Multipart::Parser`
  def self.parse(request : HTTP::Request, &)
    if content_type = request.headers["Content-Type"]?
      boundary = parse_boundary(content_type)
    end
    return nil unless boundary

    body = request.body
    return nil unless body
    parse(body, boundary) { |headers, io| yield headers, io }
  end

  # Parses a MIME multipart message, yielding `HTTP::Headers` and an `IO` for
  # each body part.
  #
  # Please note that the IO object yielded to the block is only valid while the
  # block is executing. The IO is closed as soon as the supplied block returns.
  #
  # ```
  # require "http"
  # require "mime/multipart"
  #
  # headers = HTTP::Headers{"Content-Type" => "multipart/byteranges; boundary=aA40"}
  # body = "--aA40\r\nContent-Type: text/plain\r\n\r\nbody\r\n--aA40--"
  # response = HTTP::Client::Response.new(
  #   status: :ok,
  #   headers: headers,
  #   body: body,
  # )
  #
  # MIME::Multipart.parse(response) do |headers, io|
  #   headers["Content-Type"] # => "text/plain"
  #   io.gets_to_end          # => "body"
  # end
  # ```
  #
  # See: `Multipart::Parser`
  def self.parse(response : HTTP::Client::Response, &)
    if content_type = response.headers["Content-Type"]?
      boundary = parse_boundary(content_type)
    end
    return nil unless boundary

    if body = response.body.presence
      body = IO::Memory.new(body)
    else
      body = response.body_io?
    end
    return nil unless body

    parse(body, boundary) { |headers, io| yield headers, io }
  end

  # Yields a `Multipart::Builder` to the given block, writing to *io* and
  # using *boundary*. `#finish` is automatically called on the builder.
  def self.build(io : IO, boundary : String = Multipart.generate_boundary, &)
    builder = Builder.new(io, boundary)
    yield builder
    builder.finish
  end

  # Yields a `Multipart::Builder` to the given block, returning the generated
  # message as a `String`.
  def self.build(boundary : String = Multipart.generate_boundary, &)
    String.build do |io|
      build(io, boundary) { |g| yield g }
    end
  end

  # Returns a unique string suitable for use as a multipart boundary.
  #
  # ```
  # require "mime/multipart"
  #
  # MIME::Multipart.generate_boundary # => "---------------------------dQu6bXHYb4m5zrRC3xPTGwV"
  # ```
  def self.generate_boundary : String
    "--------------------------#{Random::Secure.urlsafe_base64(18)}"
  end

  class Error < Exception
  end
end
