require "../common"
require "uri"
require "http/params"

class HTTP::Client::Request
  getter method : String
  getter headers : Headers
  getter body : String?
  getter version : String
  @cookies : Cookies?
  @query_params : Params?
  @uri : URI?

  def initialize(@method : String, @resource : String, headers : Headers? = nil, @body = nil, @version = "HTTP/1.1")
    @headers = headers.try(&.dup) || Headers.new
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
    HTTP.serialize_headers_and_body(io, headers, @body, nil, @version)
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
