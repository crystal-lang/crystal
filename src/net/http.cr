require "socket"
require "uri"
require "json"
require "ssl"

def parse_headers_and_body(io)
  headers = Hash(String, String).new(nil, Hash::CaseInsensitiveComparator)

  while line = io.gets
    if line == "\r\n" || line == "\n"
      body = nil
      if content_length = headers["content-length"]?
        body = io.read(content_length.to_i)
      elsif headers["transfer-encoding"]? == "chunked"
        body = read_chunked_body(io)
      end

      yield headers, body
      break
    end

    name, value = line.chomp.split ':', 2
    headers[name] = value.lstrip
  end
end

def read_chunked_body(io)
  String.build do |builder|
    while (chunk_size = io.gets.not_nil!.to_i(16)) > 0
      builder << io.read(chunk_size)
      io.read(2) # Read \r\n
    end
    io.read(2) # Read \r\n
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

    if (body = @body)
      new_headers = @headers ||= {} of String => String
      new_headers["Content-Length"] = body.length.to_s
    end
  end

  def to_io(io)
    io << @method << " " << @path << " HTTP/1.1\r\n"
    serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    request_line = io.gets.not_nil!
    request_line =~ /\A(\w+)\s([^\s]+)\s(HTTP\/\d\.\d)\r?\n\Z/
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
    status_line =~ /\A(HTTP\/\d\.\d)\s(\d\d\d)\s(.*?)\r?\n\Z/

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
      HTTPResponse.from_io(socket)
    end
  end

  def self.exec_ssl(host, port, request)
    TCPSocket.open(host, port) do |socket|
      SSLSocket.open(socket) do |ssl_socket|
        request.to_io(ssl_socket)
        HTTPResponse.from_io(ssl_socket)
      end
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
    Json.parse(get(url).body.not_nil!)
  end

  def self.post(url, body)
    exec_url(url) do |path, headers|
      HTTPRequest.new("POST", path, headers, body)
    end
  end

  # private

  def self.exec_url(url)
    uri = URI.parse(url)
    host_header = uri.port ? "#{uri.host}:#{uri.port}" : uri.host
    request = yield uri.full_path, {"Host" => host_header}

    case uri.scheme
    when "http" then exec(uri.host, uri.port || 80, request)
    when "https" then exec_ssl(uri.host, uri.port || 443, request)
    else raise "Unsuported scheme: #{uri.scheme}"
    end
  end
end
