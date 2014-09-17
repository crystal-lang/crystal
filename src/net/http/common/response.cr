require "common"

class HTTP::Response
  getter version
  getter status_code
  getter status_message
  getter headers
  getter body

  def initialize(@status_code, @body = nil, @headers = {} of String => String, status_message = nil, @version = "HTTP/1.1")
    @status_message = status_message || class.default_status_message_for(@status_code)

    if (body = @body)
      new_headers = @headers ||= {} of String => String
      new_headers["Content-Length"] = body.bytesize.to_s
    end
  end

  def self.not_found
    HTTP::Response.new(404, "Not Found", {"Content-Type" => "text/plain"})
  end

  def self.ok(content_type, body)
    HTTP::Response.new(200, body, {"Content-Type" => content_type})
  end

  def self.error(content_type, body)
    HTTP::Response.new(500, body, {"Content-Type" => content_type})
  end

  def to_io(io)
    io << @version << " " << @status_code << " " << @status_message << "\r\n"
    HTTP.serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    status_line = io.gets.not_nil!
    status_line =~ /\A(HTTP\/\d\.\d)\s(\d\d\d)\s(.*?)\r?\n\Z/

    http_version, status_code, status_message = MatchData.last[1], MatchData.last[2].to_i, MatchData.last[3]

    HTTP.parse_headers_and_body(io) do |headers, body|
      return new status_code, body, headers, status_message, http_version
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
