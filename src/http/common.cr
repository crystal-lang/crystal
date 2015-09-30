module HTTP
  DATE_PATTERNS = {"%a, %d %b %Y %H:%M:%S %z", "%A, %d-%b-%y %H:%M:%S %z", "%a %b %e %H:%M:%S %Y"}

  enum BodyType
    OnDemand
    Prohibited
    Mandatory
  end

  def self.parse_headers_and_body(io, body_type = BodyType::OnDemand : BodyType)
    headers = Headers.new

    while line = io.gets
      if line == "\r\n" || line == "\n"
        body = nil
        if body_type.prohibited?
          body = nil
        elsif content_length = headers["Content-length"]?
          body = FixedLengthContent.new(io, content_length.to_i)
        elsif headers["Transfer-encoding"]? == "chunked"
          body = ChunkedContent.new(io)
        elsif body_type.mandatory?
          body = UnknownLengthContent.new(io)
        end

        yield headers, body
        break
      end

      name, value = parse_header(line)
      headers.add(name, value)
    end
  end

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

  def self.serialize_headers_and_body(io, headers, body, version)
    # prepare either chunked response headers if protocol supports it
    # or consume the io to get the Content-Length header
    if body
      if body.is_a?(IO)
        if Response.supports_chunked?(version)
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
        buf :: UInt8[8192]
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

  def self.content_type(message)
    message.headers["Content-Type"]?.try &.[/[^;]*/]
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
end

require "./request"
require "./response"
require "./headers"
require "./content"
require "./cookie"
