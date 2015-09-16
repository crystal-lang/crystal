module HTTP
  DATE_PATTERNS = {"%a, %d %b %Y %H:%M:%S %z", "%A, %d-%b-%y %H:%M:%S %z", "%a %b %e %H:%M:%S %Y"}

  def self.parse_headers_and_body(io, mandatory_body = false)
    headers = Headers.new

    while line = io.gets
      if line == "\r\n" || line == "\n"
        body = nil
        if content_length = headers["Content-length"]?
          body = FixedLengthContent.new(io, content_length.to_i)
        elsif headers["Transfer-encoding"]? == "chunked"
          body = ChunkedContent.new(io)
        elsif mandatory_body
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

  def self.read_chunked_body(io)
    String.build do |builder|
      while (chunk_size = io.gets.not_nil!.to_i(16)) > 0
        builder << io.read(chunk_size)
        io.read(2) # Read \r\n
      end
      io.read(2) # Read \r\n
    end
  end

  def self.serialize_headers_and_body(io, headers, body)
    if headers
      headers.each do |name, values|
        values.each do |value|
          io << name << ": " << value << "\r\n"
        end
      end
    end

    io << "\r\n"
    io << body if body
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
