require "./common"
require "uri"
require "http/params"

class HTTP::Request
  getter method : String
  getter headers : Headers
  getter body : String?
  getter version : String
  @cookies : Cookies?
  @resource : String
  @query_params : Params?
  @uri : URI?

  def initialize(@method : String, @resource, @headers : Headers = Headers.new, @body = nil, @version = "HTTP/1.1")
    if body = @body
      @headers["Content-Length"] = body.bytesize.to_s
    elsif @method == "POST" || @method == "PUT"
      @headers["Content-Length"] = "0"
    end
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
    HTTP.serialize_headers_and_body(io, headers, @body, @version)
  end

  def self.from_io(io)
    request_line = io.gets
    return unless request_line

    method, resource, http_version = request_line.split
    HTTP.parse_headers_and_body(io) do |headers, body|
      return new method, resource, headers, body.try &.gets_to_end, http_version
    end

    # Unexpected end of http request
    nil
  end

  # Lazily parses and return the request's path component.
  def path
    uri.path
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
