require "./common"
require "uri"
require "http/params"

class HTTP::Request
  BODY_PARAMS_CONTENT_TYPE = "application/x-www-form-urlencoded"

  getter method
  getter headers
  getter version

  def initialize(@method : String, @resource, @headers = Headers.new : Headers, @body = nil, @version = "HTTP/1.1")
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

  # Returns a convenience wrapper around querying and setting body url-encoded
  # params, see `HTTP::Params`.
  def body_params
    @body_params ||= parse_body_params
  end

  # Returns true if Content-Type is application/x-www-form-urlencoded.
  # Otherwise returns false.
  def has_body_params?
    headers["Content-Type"]? == BODY_PARAMS_CONTENT_TYPE
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
    HTTP.serialize_headers_and_body(io, headers, body, @version)
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

  # Lazily parses request's path component.
  delegate "path", uri

  # Sets request's path component.
  delegate "path=", uri

  # Lazily parses request's query component.
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

  # Request's body.
  def body
    update_body
    @body
  end

  private def uri
    (@uri ||= URI.parse(@resource)).not_nil!
  end

  private def parse_query_params
    HTTP::Params.parse(uri.query || "")
  end

  private def parse_body_params
    unless has_body_params?
      raise "Content-Type should be #{BODY_PARAMS_CONTENT_TYPE} to use #body_params"
    end

    HTTP::Params.parse(body || "")
  end

  private def update_query_params
    return unless @query_params
    @query_params = parse_query_params
  end

  private def update_uri
    return unless @query_params
    uri.query = query_params.to_s
  end

  private def update_body
    return unless @body_params
    @body = body_params.to_s
  end
end
