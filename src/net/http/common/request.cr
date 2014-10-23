require "common"

class HTTP::Request
  getter method
  getter path
  getter headers
  getter body
  getter version

  def initialize(@method : String, @path, @headers = HTTP::Headers.new : HTTP::Headers, @body = nil, @version = "HTTP/1.1")
    if body = @body
      @headers["Content-Length"] = body.bytesize.to_s
    elsif @method == "POST" || @method == "PUT"
      @headers["Content-Length"] = "0"
    end
  end

  def uri
    URI.parse(@path)
  end

  def keep_alive?
    case @headers.try(&.["Connection"]?).try &.downcase
    when "keep-alive"
      return true
    when "close"
      return false
    end

    case @version
    when "HTTP/1.0"
      false
    else
      true
    end
  end

  def to_io(io)
    io << @method << " " << @path << " " << @version << "\r\n"
    HTTP.serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    request_line = io.gets.not_nil!
    request_line =~ /\A(\w+)\s([^\s]+)\s(HTTP\/\d\.\d)\r?\n\Z/
    method, path, http_version = $1, $2, $3

    HTTP.parse_headers_and_body(io) do |headers, body|
      return new method, path, headers, body, http_version
    end

    raise "unexpected end of http request"
  end
end
