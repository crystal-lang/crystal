require "mime/media_type"
{% if !flag?(:without_zlib) %}
  require "flate"
  require "gzip"
{% end %}

module HTTP
  # :nodoc:
  MAX_HEADER_SIZE = 16_384

  # :nodoc:
  enum BodyType
    OnDemand
    Prohibited
    Mandatory
  end

  SUPPORTED_VERSIONS = {"HTTP/1.0", "HTTP/1.1"}

  # :nodoc:
  def self.parse_headers_and_body(io, body_type : BodyType = BodyType::OnDemand, decompress = true)
    headers = Headers.new

    headers_size = 0
    while line = io.gets(MAX_HEADER_SIZE, chomp: true)
      headers_size += line.bytesize
      break if headers_size > MAX_HEADER_SIZE

      if line.empty?
        body = nil

        if body_type.prohibited?
          body = nil
        elsif content_length = content_length(headers)
          if content_length != 0
            # Don't create IO for Content-Length == 0
            body = FixedLengthContent.new(io, content_length)
          end
        elsif headers["Transfer-Encoding"]? == "chunked"
          body = ChunkedContent.new(io)
        elsif body_type.mandatory?
          body = UnknownLengthContent.new(io)
        end

        if body.is_a?(Content) && expect_continue?(headers)
          body.expects_continue = true
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

    content_type = headers["Content-Type"]?
    return unless content_type

    mime_type = MIME::MediaType.parse?(content_type)
    return unless mime_type

    charset = mime_type["charset"]?
    return unless charset

    body.set_encoding(charset, invalid: :skip)
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
    length_headers = headers.get? "Content-Length"
    return nil unless length_headers
    first_header = length_headers[0]
    if length_headers.size > 1 && length_headers.any? { |header| header != first_header }
      raise ArgumentError.new("Multiple Content-Length headers received did not match: #{length_headers}")
    end
    first_header.to_u64
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

  def self.expect_continue?(headers)
    headers["Expect"]?.try(&.downcase) == "100-continue"
  end

  # Parse a time string using the formats specified by [RFC 2616](https://tools.ietf.org/html/rfc2616#section-3.3.1)
  #
  # ```
  # require "http"
  #
  # HTTP.parse_time("Sun, 14 Feb 2016 21:00:00 GMT")  # => "2016-02-14 21:00:00 UTC"
  # HTTP.parse_time("Sunday, 14-Feb-16 21:00:00 GMT") # => "2016-02-14 21:00:00 UTC"
  # HTTP.parse_time("Sun Feb 14 21:00:00 2016")       # => "2016-02-14 21:00:00 UTC"
  # ```
  #
  # Uses `Time::Format::HTTP_DATE` as parser.
  def self.parse_time(time_str : String) : Time?
    Time::Format::HTTP_DATE.parse(time_str)
  rescue Time::Format::Error
  end

  # Format a `Time` object as a `String` using the format specified as `sane-cookie-date`
  # by [RFC 6265](https://tools.ietf.org/html/rfc6265#section-4.1.1) which is
  # according to [RFC 2616](https://tools.ietf.org/html/rfc2616#section-3.3.1) a
  # [RFC 1123](https://tools.ietf.org/html/rfc1123#page-55) format with explicit
  # timezone `GMT` (interpreted as `UTC`).
  #
  # ```
  # require "http"
  #
  # HTTP.format_time(Time.utc(2016, 2, 15)) # => "Mon, 15 Feb 2016 00:00:00 GMT"
  # ```
  #
  # Uses `Time::Format::HTTP_DATE` as formatter.
  def self.format_time(time : Time) : String
    Time::Format::HTTP_DATE.format(time)
  end

  # Dequotes an [RFC 2616](https://tools.ietf.org/html/rfc2616#page-17)
  # quoted-string.
  #
  # ```
  # require "http"
  #
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
  # require "http"
  #
  # string = %q("foo\ bar")
  # io = IO::Memory.new
  # HTTP.quote_string(string, io)
  # io.rewind
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
  # require "http"
  #
  # string = %q("foo\ bar")
  # HTTP.quote_string(string) # => %q(\"foo\\\ bar\")
  # ```
  def self.quote_string(string)
    String.build do |io|
      quote_string(string, io)
    end
  end
end

require "./status"
require "./request"
require "./client/response"
require "./headers"
require "./content"
require "./cookie"
