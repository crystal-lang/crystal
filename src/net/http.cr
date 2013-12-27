require "socket"
require "uri"

class HTTPRequest
  def initialize(@host, @port, method, @path, @headers = nil)
    @method = case method
    when :get then "GET"
    else method
    end
  end

  def to_io(io)
    io << @method << " " << @path << " HTTP/1.1\r\n"
    io << "Host: " << @host << ":" << @port << "\r\n"
    io << "\r\n"
  end
end

class HTTPResponse
  def self.from_io(io)
    status_line = io.gets.not_nil!
    status_line =~ Regexp.new("(HTTP/\\d\\.\\d)\\s(\\d\\d\\d)\\s(.*)\\r\\n$")
    http_version, status_code, status_message = $1, $2.to_i, $3

    headers = {} of String => String

    while line = io.gets
      if line == "\r\n"
        return new http_version, status_code, status_message, headers, io.read(headers["content-length"].to_i)
      end

      name, value = line.chomp.split ':', 2
      headers[name.downcase] = value.lstrip
    end

    raise "unexpected end of http response"
  end

  def initialize(@version, @status_code, @status_message, @headers, @body)
  end

  getter version
  getter status_code
  getter status_message
  getter headers
  getter body
end

class HTTPClient
  def self.get(host, port, path)
    TCPSocket.open(host, port) do |socket|
      request = HTTPRequest.new(host, port, "GET", path)
      request.to_io(socket)
      socket.flush
      HTTPResponse.from_io(socket)
    end
  end

  def self.get(url : String)
    uri = URI.parse(url)
    get(uri.host, uri.port, uri.full_path)
  end
end
