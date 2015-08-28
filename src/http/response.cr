require "./common"

module HTTP
  class InvalidResponse < Exception
    def initialize(message = "Invalid HTTP::Response")
      super(message)
    end
  end
end

class HTTP::Response
  getter version
  getter status_code
  getter status_message
  getter headers
  property upgrade_handler

  def initialize(@status_code, body = nil, @headers = Headers.new : Headers, status_message = nil, @version = "HTTP/1.1")
    @status_message = status_message || self.class.default_status_message_for(@status_code)

    if @status_code / 100 == 1 || @status_code == 204 || @status_code == 304
      if body
        raise ArgumentError.new("status #{status_code} should not have a body")
      end
    else
      body = "" unless body
    end

    if body.is_a? String
      @body_io = StringIO.new(body)
      @headers["Content-length"] = body.bytesize.to_s
    else
      @body_io = body
    end
  end

  def body_io
    @body_io || EmptyContent.new
  end
  
  def body
    if body_io.pos != 0
      raise ArgumentError.new("cannot use #body after a read on #body_io")
    end
    body_io.read
  end

  def body?
    !!@body_io
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
    HTTP.serialize_headers_and_body(io, @headers, @body_io)
  end
  
  def self.from_io(io)
    line = io.gets
    if line
      http_version, status_code, status_message = line.split(3)
      status_code = status_code.to_i
      status_message = status_message.chomp
      shouldnt_have_body = (status_code / 100 == 1 || status_code == 204 || status_code == 304)

      HTTP.parse_headers_and_body(io) do |headers, body|
        if shouldnt_have_body && body
          raise InvalidResponse.new("status #{status_code} should not have a body")
        end
        
        return new status_code, body, headers, status_message, http_version
      end
    end

    raise InvalidResponse.new("unexpected end of http response")
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
