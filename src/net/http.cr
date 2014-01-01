require "socket"
require "uri"
require "yaml"

def parse_headers_and_body(io)
  headers = {} of String => String

  while line = io.gets
    if line == "\r\n"
      body = nil
      if content_length = headers["content-length"]?
        body = io.read(content_length.to_i)
      end

      yield headers, body
      break
    end

    name, value = line.chomp.split ':', 2
    headers[name.downcase] = value.lstrip
  end
end

def serialize_headers_and_body(io, headers, body)
  if headers
    headers.each do |name, value|
      io << name << ": " << value << "\r\n"
    end
  end
  io << "\r\n"
  io << body if body
end

class HTTPRequest
  def initialize(method, @path, @headers = nil, @body = nil)
    @method = case method
    when :get then "GET"
    when :post then "POST"
    else method
    end

    if (body = @body) && @headers.nil?
      headers = @headers = {} of String => String
      headers["Content-Length"] = body.length.to_s
    end
  end

  def to_io(io)
    io << @method << " " << @path << " HTTP/1.1\r\n"
    serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    request_line = io.gets.not_nil!
    request_line =~ /\A(\w+)\s([^\s]+)\s(HTTP\/\d\.\d)\r\n\Z/
    method, path, http_version = $1, $2, $3

    parse_headers_and_body(io) do |headers, body|
      return new method, path, headers, body
    end

    raise "unexpected end of http request"
  end

  getter method
  getter path
  getter headers
  getter body
end

class HTTPResponse
  def initialize(@version, @status_code, @status_message, @headers, @body)
  end

  def to_io(io)
    io << @version << " " << @status_code << " " << @status_message << "\r\n"
    serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    status_line = io.gets.not_nil!
    status_line =~ /\A(HTTP\/\d\.\d)\s(\d\d\d)\s(.*)\r\n\Z/
    http_version, status_code, status_message = $1, $2.to_i, $3

    parse_headers_and_body(io) do |headers, body|
      return new http_version, status_code, status_message, headers, body
    end

    raise "unexpected end of http response"
  end

  getter version
  getter status_code
  getter status_message
  getter headers
  getter body
end

class HTTPClient
  def self.exec(host, port, request)
    TCPSocket.open(host, port) do |socket|
      request.to_io(socket)
      socket.flush
      HTTPResponse.from_io(socket)
    end
  end

  def self.get(host, port, path, headers = nil)
    exec(host, port, HTTPRequest.new("GET", path, headers))
  end

  def self.get(url)
    exec_url(url) do |path, headers|
      HTTPRequest.new("GET", path, headers)
    end
  end

  def self.get_json(url)
    Yaml.load(get(url).body)
  end

  def self.post(url, body)
    exec_url(url) do |path, headers|
      HTTPRequest.new("POST", path, headers, body)
    end
  end

  # private

  def self.exec_url(url)
    uri = URI.parse(url)
    if uri_port = uri.port
      host_header = "#{uri.host}:#{uri.port}"
      port = uri_port
    else
      host_header = uri.host
      port = case uri.scheme
      when "http" then 80
      else raise "Unsuported scheme: #{uri.scheme}"
      end
    end

    request = yield uri.full_path, {"Host" => host_header}
    exec(uri.host, port, request)
  end
end
