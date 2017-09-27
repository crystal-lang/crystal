require "./common"
require "uri"
require "http/params"

# An HTTP request.
#
# It serves both to perform requests by an `HTTP::Client` and to
# represent requests received by an `HTTP::Server`.
#
# A request always holds an `IO` as a body.
# When creating a request with a `String` or `Bytes` its body
# will be a `IO::Memory` wrapping these, and the `Content-Length`
# header will be set appropriately.
class HTTP::Request
  property method : String
  property headers : Headers
  getter body : IO?
  property version : String
  @cookies : Cookies?
  @query_params : Params?
  @uri : URI?

  def initialize(@method : String, @resource : String, headers : Headers? = nil, body : String | Bytes | IO | Nil = nil, @version = "HTTP/1.1")
    @headers = headers.try(&.dup) || Headers.new
    self.body = body
  end

  # Returns a convenience wrapper around querying and setting cookie related
  # headers, see `HTTP::Cookies`.
  def cookies
    @cookies ||= Cookies.from_headers(headers)
  end

  # Returns a convenience wrapper around querying and setting query params,
  # see `HTTP::Params`.
  def query_params
    @query_params ||= parse_query_params
  end

  def resource
    update_uri
    @uri.try(&.full_path) || @resource
  end

  def keep_alive?
    HTTP.keep_alive?(self)
  end

  def ignore_body?
    @method == "HEAD"
  end

  def content_length=(length : Int)
    headers["Content-Length"] = length.to_s
  end

  def content_length
    HTTP.content_length(headers)
  end

  def body=(body : String)
    @body = IO::Memory.new(body)
    self.content_length = body.bytesize
  end

  def body=(body : Bytes)
    @body = IO::Memory.new(body)
    self.content_length = body.size
  end

  def body=(@body : IO)
  end

  def body=(@body : Nil)
    @headers["Content-Length"] = "0" if @method == "POST" || @method == "PUT"
  end

  def to_io(io)
    io << @method << " " << resource << " " << @version << "\r\n"
    cookies = @cookies
    headers = cookies ? cookies.add_request_headers(@headers) : @headers
    HTTP.serialize_headers_and_body(io, headers, nil, @body, @version)
  end

  # :nodoc:
  record BadRequest

  # Returns a `HTTP::Request` instance if successfully parsed,
  # `nil` on EOF or `BadRequest` otherwise.
  def self.from_io(io)
    request_line = io.gets(4096, chomp: true)
    return unless request_line

    parts = request_line.split
    return BadRequest.new unless parts.size == 3

    method, resource, http_version = parts
    HTTP.parse_headers_and_body(io) do |headers, body|
      return new method, resource, headers, body, http_version
    end

    # Malformed or unexpectedly ended http request
    BadRequest.new
  end

  # Lazily parses and return the request's path component.
  def path
    uri.path || "/"
  end

  # Sets request's path component.
  def path=(path)
    uri.path = path
  end

  # Lazily parses and returns the request's query component.
  def query
    update_uri
    uri.query
  end

  # Sets request's query component.
  def query=(value)
    uri.query = value
    update_query_params
    value
  end

  # Return request host from headers.
  def host
    host = @headers["Host"]?
    return unless host
    index = host.index(":")
    index ? host[0...index] : host
  end

  # Return request host with port from headers.
  def host_with_port
    @headers["Host"]?
  end

  private def uri
    (@uri ||= URI.parse(@resource)).not_nil!
  end

  private def parse_query_params
    HTTP::Params.parse(uri.query || "")
  end

  private def update_query_params
    return unless @query_params
    @query_params = parse_query_params
  end

  private def update_uri
    return unless @query_params
    uri.query = query_params.to_s
  end
end
