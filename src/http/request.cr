require "./common"
require "uri"

class HTTP::Request
  getter method
  getter path
  getter headers
  getter body
  getter version

  def initialize(@method : String, @path, @headers = Headers.new : Headers, @body = nil, @version = "HTTP/1.1")
    if body = @body
      @headers["Content-length"] = body.bytesize.to_s
    elsif @method == "POST" || @method == "PUT"
      @headers["Content-length"] = "0"
    end
  end

  def uri
    URI.parse(@path)
  end

  def keep_alive?
    HTTP.keep_alive?(self)
  end

  def to_io(io)
    io << @method << " " << @path << " " << @version << "\r\n"
    HTTP.serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    request_line = io.gets
    return unless request_line

    method, path, http_version = request_line.split
    HTTP.parse_headers_and_body(io) do |headers, body|
      return new method, path, headers, body, http_version
    end

    # Unexpected end of http request
    nil
  end
end
