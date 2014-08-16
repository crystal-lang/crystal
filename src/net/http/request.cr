class HTTP::Request
  getter method
  getter path
  getter headers
  getter body

  def initialize(method, @path, @headers = nil, @body = nil)
    @method = case method
    when :get then "GET"
    when :post then "POST"
    else method
    end

    if (body = @body)
      new_headers = @headers ||= {} of String => String
      new_headers["Content-Length"] = body.bytesize.to_s
    end
  end

  def to_io(io)
    io << @method << " " << @path << " HTTP/1.1\r\n"
    HTTP.serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    request_line = io.gets.not_nil!
    request_line =~ /\A(\w+)\s([^\s]+)\s(HTTP\/\d\.\d)\r?\n\Z/
    method, path, http_version = $1, $2, $3

    HTTP.parse_headers_and_body(io) do |headers, body|
      return new method, path, headers, body
    end

    raise "unexpected end of http request"
  end
end
