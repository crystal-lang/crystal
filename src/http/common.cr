{% if !flag?(:without_zlib) %}
  require "flate"
  require "gzip"
{% end %}

module HTTP
  private DATE_PATTERNS = {"%a, %d %b %Y %H:%M:%S %z", "%d %b %Y %H:%M:%S %z", "%A, %d-%b-%y %H:%M:%S %z", "%a %b %e %H:%M:%S %Y"}

  # :nodoc:
  enum BodyType
    OnDemand
    Prohibited
    Mandatory
  end

  # :nodoc:
  def self.parse_headers_and_body(io, body_type : BodyType = BodyType::OnDemand, decompress = true)
    headers = Headers.new

    headers_size = 0
    while line = io.gets(16_384, chomp: true)
      headers_size += line.bytesize
      break if headers_size > 16_384

      if line.empty?
        body = nil
        if body_type.prohibited?
          body = nil
        elsif content_length = headers["Content-Length"]?
          content_length = content_length.to_u64
          if content_length != 0
            # Don't create IO for Content-Length == 0
            body = FixedLengthContent.new(io, content_length)
          end
        elsif headers["Transfer-Encoding"]? == "chunked"
          body = ChunkedContent.new(io)
        elsif body_type.mandatory?
          body = UnknownLengthContent.new(io)
        end

        if decompress && body
          {% if flag?(:without_zlib) %}
            raise "Can't decompress because `-D without_zlib` was passed at compile time"
          {% else %}
            encoding = headers["Content-Encoding"]?
            case encoding
            when "gzip"
              body = Gzip::Reader.new(body, sync_close: true)
            when "deflate"
              body = Flate::Reader.new(body, sync_close: true)
            end
          {% end %}
        end

        check_content_type_charset(body, headers)

        yield headers, body
        break
      end

      name, value = parse_header(line)
      break unless headers.add?(name, value)
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
    # ```
    # line = "Server: nginx"
    # name, value = line.split ':', 2
    # {name, value.lstrip} # => {"Server", "nginx"}
    # ```
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
    while middle_index < bytesize && cstr[middle_index].unsafe_chr.ascii_whitespace?
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
  def self.serialize_headers_and_body(io, headers, body, body_io, version)
    if body
      serialize_headers_and_string_body(io, headers, body)
    elsif body_io
      content_length = content_length(headers)
      if content_length
        serialize_headers(io, headers)
        copied = IO.copy(body_io, io)
        if copied != content_length
          raise ArgumentError.new("Content-Length header is #{content_length} but body had #{copied} bytes")
        end
      elsif Client::Response.supports_chunked?(version)
        headers["Transfer-Encoding"] = "chunked"
        serialize_headers(io, headers)
        serialize_chunked_body(io, body_io)
      else
        body = body_io.gets_to_end
        serialize_headers_and_string_body(io, headers, body)
      end
    else
      serialize_headers(io, headers)
    end
  end

  def self.serialize_headers_and_string_body(io, headers, body)
    headers["Content-Length"] = body.bytesize.to_s
    serialize_headers(io, headers)
    io << body
  end

  def self.serialize_headers(io, headers)
    headers.each do |name, values|
      values.each do |value|
        io << name << ": " << value << "\r\n"
      end
    end
    io << "\r\n"
  end

  def self.serialize_chunked_body(io, body)
    buf = uninitialized UInt8[8192]
    while (buf_length = body.read(buf.to_slice)) > 0
      buf_length.to_s(16, io)
      io << "\r\n"
      io.write(buf.to_slice[0, buf_length])
      io << "\r\n"
    end
    io << "0\r\n\r\n"
  end

  # :nodoc:
  def self.content_length(headers)
    headers["Content-Length"]?.try &.to_u64?
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
      content_type = pieces[0].strip
      (1...pieces.size).each do |i|
        piece = pieces[i]
        eq_index = piece.index('=')
        if eq_index
          key = piece[0...eq_index].strip
          if key == "charset"
            value = piece[eq_index + 1..-1].strip
            return ComputedContentTypeHeader.new(content_type, value)
          end
        end
      end
    else
      content_type = content_type.strip
    end

    ComputedContentTypeHeader.new(content_type.strip, nil)
  end

  def self.parse_time(time_str : String) : Time?
    DATE_PATTERNS.each do |pattern|
      begin
        return Time.parse(time_str, pattern, kind: Time::Kind::Utc)
      rescue Time::Format::Error
      end
    end

    nil
  end

  # Format a Time object as a String using the format specified by [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55).
  #
  # ```
  # HTTP.rfc1123_date(Time.new(2016, 2, 15)) # => "Sun, 14 Feb 2016 21:00:00 GMT"
  # ```
  def self.rfc1123_date(time : Time) : String
    # TODO: GMT should come from the Time classes instead
    time.to_utc.to_s("%a, %d %b %Y %H:%M:%S GMT")
  end

  # Dequotes an [RFC 2616](https://tools.ietf.org/html/rfc2616#page-17)
  # quoted-string.
  #
  # ```
  # quoted = %q(\"foo\\bar\")
  # HTTP.dequote_string(quoted) # => %q("foo\bar")
  # ```
  def self.dequote_string(str)
    data = str.to_slice
    quoted_pair_index = data.index('\\'.ord)
    return str unless quoted_pair_index

    String.build do |io|
      while quoted_pair_index
        io.write(data[0, quoted_pair_index])
        io << data[quoted_pair_index + 1].chr

        data += quoted_pair_index + 2
        quoted_pair_index = data.index('\\'.ord)
      end
      io.write(data)
    end
  end

  # Encodes a string to an [RFC 2616](https://tools.ietf.org/html/rfc2616#page-17)
  # quoted-string. Encoded string is written to *io*. May raise when *string*
  # contains an invalid character.
  #
  # ```
  # string = %q("foo\ bar")
  # io = IO::Memory.new
  # HTTP.quote_string(string, io)
  # io.gets_to_end # => %q(\"foo\\\ bar\")
  # ```
  def self.quote_string(string, io)
    # Escaping rules: https://evolvis.org/pipermail/evolvis-platfrm-discuss/2014-November/000675.html

    string.each_byte do |byte|
      case byte
      when '\t'.ord, ' '.ord, '"'.ord, '\\'.ord
        io << '\\'
      when 0x00..0x1F, 0x7F
        raise ArgumentError.new("String contained invalid character #{byte.chr.inspect}")
      end
      io.write_byte byte
    end
  end

  # Encodes a string to an [RFC 2616](https://tools.ietf.org/html/rfc2616#page-17)
  # quoted-string. May raise when *string* contains an invalid character.
  #
  # ```
  # string = %q("foo\ bar")
  # HTTP.quote_string(string) # => %q(\"foo\\\ bar\")
  # ```
  def self.quote_string(string)
    String.build do |io|
      quote_string(string, io)
    end
  end

  # Returns the default status message of the given HTTP status code.
  #
  # Based on [Hypertext Transfer Protocol (HTTP) Status Code Registry](https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml)
  #
  # Last Updated 2017-04-14
  #
  # HTTP Status Codes (source: [http-status-codes-1.csv](https://www.iana.org/assignments/http-status-codes/http-status-codes-1.csv))
  #
  # * 1xx: Informational - Request received, continuing process
  # * 2xx: Success - The action was successfully received, understood, and accepted
  # * 3xx: Redirection - Further action must be taken in order to complete the request
  # * 4xx: Client Error - The request contains bad syntax or cannot be fulfilled
  # * 5xx: Server Error - The server failed to fulfill an apparently valid request
  #
  def self.default_status_message_for(status_code : Int) : String
    case status_code
    when 100 then "Continue"
    when 101 then "Switching Protocols"
    when 102 then "Processing"
    when 200 then "OK"
    when 201 then "Created"
    when 202 then "Accepted"
    when 203 then "Non-Authoritative Information"
    when 204 then "No Content"
    when 205 then "Reset Content"
    when 206 then "Partial Content"
    when 207 then "Multi-Status"
    when 208 then "Already Reported"
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
    when 413 then "Payload Too Large"
    when 414 then "URI Too Long"
    when 415 then "Unsupported Media Type"
    when 416 then "Range Not Satisfiable"
    when 417 then "Expectation Failed"
    when 421 then "Misdirected Request"
    when 422 then "Unprocessable Entity"
    when 423 then "Locked"
    when 424 then "Failed Dependency"
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
    when 507 then "Insufficient Storage"
    when 508 then "Loop Detected"
    when 510 then "Not Extended"
    when 511 then "Network Authentication Required"
    else          ""
    end
  end
end

require "./request"
require "./client/response"
require "./headers"
require "./content"
require "./cookie"
