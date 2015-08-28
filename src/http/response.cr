require "./common"

class HTTP::Response
  getter version
  getter status_code
  getter status_message
  getter headers
  getter! body_io
  property upgrade_handler

  def initialize(@status_code, @body = nil, @headers = Headers.new : Headers, status_message = nil, @version = "HTTP/1.1", @body_io = nil)
    @status_message = status_message || self.class.default_status_message_for(@status_code)

    if (body = @body)
      @headers["Content-length"] = body.bytesize.to_s
    end
  end

  def body
    @body || ""
  end

  def body?
    @body
  end

  def keep_alive?
    HTTP.keep_alive?(self)
  end

  def self.not_found
    new(404, "Not Found", Headers{"Content-type": "text/plain"})
  end

  def self.ok(content_type, body)
    new(200, body, Headers{"Content-type": content_type})
  end

  def self.error(content_type, body)
    new(500, body, Headers{"Content-type": content_type})
  end

  def self.unauthorized
    new(401, "Unauthorized", Headers{"Content-type": "text/plain"})
  end

  def to_io(io)
    io << @version << " " << @status_code << " " << @status_message << "\r\n"
    HTTP.serialize_headers_and_body(io, @headers, @body)
  end
  
  # :nodoc:
  def consume_body_io
    if io = @body_io
      @body = io.read
      @body_io = nil
    end
  end

  def self.from_io(io)
    from_io(io) do |response|
      response.consume_body_io
      return response
    end
  end

  def self.from_io(io, &block)
    line = io.gets
    if line
      http_version, status_code, status_message = line.split(3)
      status_code = status_code.to_i
      status_message = status_message.chomp

      HTTP.parse_headers_and_body(io) do |headers, body|
        return yield new status_code, nil, headers, status_message, http_version, body
      end
    end

    raise "unexpected end of http response"
  end

  def self.default_status_message_for(status_code)
    case status_code
    when 100 then "Continue"
    when 101 then "Switching Protocols"
    when 200 then "OK"
    when 201 then "Created"
    when 202 then "Accepted"
    when 203 then "Non-Authoritative Information"
    when 204 then "No Content"
    when 205 then "Reset Content"
    when 206 then "Partial Content"
    when 300 then "Multiple Choices"
    when 301 then "Moved Permanently"
    when 302 then "Found"
    when 303 then "See Other"
    when 304 then "Not Modified"
    when 305 then "Use Proxy"
    when 307 then "Temporary Redirect"
    when 400 then "Bad Request"
    when 401 then "Unauthorized"
    when 402 then "Payment Required"
    when 403 then "Forbidden"
    when 404 then "Not Found"
    when 405 then "Method Not Allowed"
    when 406 then "Not Acceptable"
    when 407 then "Proxy Authentication Required"
    when 408 then "Request Timeout"
    when 409 then "Conflict"
    when 410 then "Gone"
    when 411 then "Length Required"
    when 412 then "Precondition Failed"
    when 413 then "Request Entity Too Large"
    when 414 then "Request-URI Too Long"
    when 415 then "Unsupported Media Type"
    when 416 then "Requested Range Not Satisfiable"
    when 417 then "Expectation Failed"
    when 500 then "Internal Server Error"
    when 501 then "Not Implemented"
    when 502 then "Bad Gateway"
    when 503 then "Service Unavailable"
    when 504 then "Gateway Timeout"
    when 505 then "HTTP Version Not Supported"
    else ""
    end
  end
end
