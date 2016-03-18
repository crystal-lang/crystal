require "zlib" ifdef !without_zlib

module HTTP
  # :nodoc:
  DATE_PATTERNS = {"%a, %d %b %Y %H:%M:%S %z", "%A, %d-%b-%y %H:%M:%S %z", "%a %b %e %H:%M:%S %Y"}

  # :nodoc:
  enum BodyType
    OnDemand
    Prohibited
    Mandatory
  end

  # :nodoc:
  def self.parse_headers_and_body(io, body_type : BodyType = BodyType::OnDemand, decompress = true)
    headers = Headers.new

    while line = io.gets
      if line == "\r\n" || line == "\n"
        body = nil
        if body_type.prohibited?
          body = nil
        elsif content_length = headers["Content-Length"]?
          body = FixedLengthContent.new(io, content_length.to_u64)
        elsif headers["Transfer-Encoding"]? == "chunked"
          body = ChunkedContent.new(io)
        elsif body_type.mandatory?
          body = UnknownLengthContent.new(io)
        end

        if decompress && body
          ifdef without_zlib
            raise "Can't decompress because `-D without_zlib` was passed at compile time"
          else
            encoding = headers["Content-Encoding"]?
            case encoding
            when "gzip"
              body = Zlib::Inflate.gzip(body, sync_close: true)
            when "deflate"
              body = Zlib::Inflate.new(body, sync_close: true)
            end
          end
        end

        check_content_type_charset(body, headers)

        yield headers, body
        break
      end

      name, value = parse_header(line)
      headers.add(name, value)
    end
  end

  private def self.check_content_type_charset(body, headers)
    return unless body

    if charset = content_type_and_charset(headers).charset
      body.set_encoding(charset, invalid: :skip)
    end
  end

  # :nodoc:
  def self.parse_header(line)
    # This is basically
    #
    #     name, value = line.split ':', 2
    #     {name, value.lstrip}
    #
    # except that it's faster because we only create 2 strings
    # instead of 3 (two from the split and one for the lstrip),
    # and there's no need for the array returned by split.

    cstr = line.to_unsafe
    bytesize = line.bytesize

    # Get the colon index and name
    colon_index = cstr.to_slice(bytesize).index(':'.ord) || 0
    name = line.byte_slice(0, colon_index)

    # Get where the header value starts (skip space)
    middle_index = colon_index + 1
    while middle_index < bytesize && cstr[middle_index].chr.whitespace?
      middle_index += 1
    end

    # Get where the header value ends (chomp line)
    right_index = bytesize
    if middle_index >= right_index
      return {name, ""}
    elsif right_index > 1 && cstr[right_index - 2] === '\r' && cstr[right_index - 1] === '\n'
      right_index -= 2
    elsif right_index > 0 && cstr[right_index - 1] === '\n'
      right_index -= 1
    end

    value = line.byte_slice(middle_index, right_index - middle_index)

    {name, value}
  end

  # :nodoc:
  def self.serialize_headers_and_body(io, headers, body, version)
    # prepare either chunked response headers if protocol supports it
    # or consume the io to get the Content-Length header
    if body
      if body.is_a?(IO)
        if Client::Response.supports_chunked?(version)
          headers["Transfer-Encoding"] = "chunked"
        else
          body = body.gets_to_end
        end
      end

      unless body.is_a?(IO)
        headers["Content-Length"] = body.bytesize.to_s
      end
    end

    headers.each do |name, values|
      values.each do |value|
        io << name << ": " << value << "\r\n"
      end
    end

    io << "\r\n"

    if body
      if body.is_a?(IO)
        buf = uninitialized UInt8[8192]
        while (buf_length = body.read(buf.to_slice)) > 0
          buf_length.to_s(16, io)
          io << "\r\n"
          io.write(buf.to_slice[0, buf_length])
          io << "\r\n"
        end
        io << "0\r\n\r\n"
      else
        io << body
      end
    end
  end

  # :nodoc:
  def self.keep_alive?(message)
    case message.headers["Connection"]?.try &.downcase
    when "keep-alive"
      return true
    when "close", "upgrade"
      return false
    end

    case message.version
    when "HTTP/1.0"
      false
    else
      true
    end
  end

  record ComputedContentTypeHeader,
    content_type : String?,
    charset : String?

  # :nodoc:
  def self.content_type_and_charset(headers)
    content_type = headers["Content-Type"]?
    return ComputedContentTypeHeader.new(nil, nil) unless content_type

    # Avoid allocating an array for the split if there's no ';'
    if content_type.index(';')
      pieces = content_type.split(';')
      (1...pieces.size).each do |i|
        piece = pieces[i]
        eq_index = piece.index('=')
        if eq_index
          key = piece[0...eq_index].strip
          if key
            value = piece[eq_index + 1..-1].strip
            return ComputedContentTypeHeader.new(pieces[0].strip, value)
          end
        end
      end
    end

    ComputedContentTypeHeader.new(content_type.strip, nil)
  end

  def self.parse_time(time_str : String)
    DATE_PATTERNS.each do |pattern|
      begin
        return Time.parse(time_str, pattern)
      rescue Time::Format::Error
      end
    end

    nil
  end

  def self.rfc1123_date(time : Time) : String
    # TODO: GMT should come from the Time classes instead
    time.to_s("%a, %d %b %Y %H:%M:%S GMT")
  end

  # Returns the default status message of the given HTTP status code.
  def self.default_status_message_for(status_code : Int)
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
    when 226 then "IM Used"
    when 300 then "Multiple Choices"
    when 301 then "Moved Permanently"
    when 302 then "Found"
    when 303 then "See Other"
    when 304 then "Not Modified"
    when 305 then "Use Proxy"
    when 307 then "Temporary Redirect"
    when 308 then "Permanent Redirect"
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
    when 421 then "Misdirected Request"
    when 423 then "Locked"
    when 426 then "Upgrade Required"
    when 428 then "Precondition Required"
    when 429 then "Too Many Requests"
    when 431 then "Request Header Fields Too Large"
    when 451 then "Unavailable For Legal Reasons"
    when 500 then "Internal Server Error"
    when 501 then "Not Implemented"
    when 502 then "Bad Gateway"
    when 503 then "Service Unavailable"
    when 504 then "Gateway Timeout"
    when 505 then "HTTP Version Not Supported"
    when 506 then "Variant Also Negotiates"
    when 510 then "Not Extended"
    else          ""
    end
  end
end

require "./request"
require "./client/response"
require "./headers"
require "./content"
require "./cookie"
