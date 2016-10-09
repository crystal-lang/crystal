require "./common"
require "uri"
require "http/params"

# An HTTP request.
#
# It serves both to perform requests by an `HTTP::Client` and to
# represent requests received by an `HTTP::Server`.
#
# In the case of an `HTTP::Server`, `#body` will always raise
# and `#body_io` will optionally have an `IO` representing the request
# body. This will be `nil` if the request has no body.
class HTTP::Request
  getter method : String
  getter headers : Headers
  getter body : String?
  getter body_io : IO?
  getter version : String
  @cookies : Cookies?
  @query_params : Params?
  @uri : URI?

  def initialize(@method : String, @resource : String, headers : Headers? = nil, @body = nil, @body_io = nil, @version = "HTTP/1.1")
    @headers = headers.try(&.dup) || Headers.new
    if body = @body
      if body_io
        raise ArgumentError.new("can't initialize HTTP::Request with both `body` and `body_io`")
      end
      @headers["Content-Length"] = body.bytesize.to_s
    elsif !@body_io && (@method == "POST" || @method == "PUT")
      @headers["Content-Length"] = "0"
    end
  end

  def body
    if @body_io
      raise "HTTP::Request has a `body_io`: use `body_io`, not `body` to get its body"
    end
    @body
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

  def to_io(io)
    io << @method << " " << resource << " " << @version << "\r\n"
    cookies = @cookies
    headers = cookies ? cookies.add_request_headers(@headers) : @headers
    HTTP.serialize_headers_and_body(io, headers, @body, @body_io, @version)
  end

  # :nodoc:
  record BadRequest

  # Returns:
  # * nil: EOF
  # * BadRequest: bad request
  # * HTTP::Request: successfully parsed
  def self.from_io(io)
    request_line = io.gets
    return unless request_line

    parts = request_line.split
    return BadRequest.new unless parts.size == 3

    method, resource, http_version = parts
    HTTP.parse_headers_and_body(io) do |headers, body_io|
      return new method, resource, headers, nil, body_io, http_version
    end

    # Unexpected end of http request
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
