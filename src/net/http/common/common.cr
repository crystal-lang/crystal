require "./*"

module HTTP
  def self.parse_headers_and_body(io)
    headers = HTTP::Headers.new

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
      headers.each do |name, value|
        io << name << ": " << value << "\r\n"
      end
    end
    io << "\r\n"
    io << body if body
  end
end
