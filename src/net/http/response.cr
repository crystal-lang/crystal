class HTTP::Response
  getter version
  getter status_code
  getter status_message
  getter headers
  getter body

  def initialize(@version, @status_code, @status_message, @headers, @body)
  end

  def self.not_found
    HTTP::Response.new("HTTP/1.1", 404, "Not Found", {"Content-Type" => "text/plain"}, "Not Found")
  end

  def to_io(io)
    io << @version << " " << @status_code << " " << @status_message << "\r\n"
    HTTP.serialize_headers_and_body(io, @headers, @body)
  end

  def self.from_io(io)
    status_line = io.gets.not_nil!
    status_line =~ /\A(HTTP\/\d\.\d)\s(\d\d\d)\s(.*?)\r?\n\Z/

    http_version, status_code, status_message = $1, $2.to_i, $3

    HTTP.parse_headers_and_body(io) do |headers, body|
      return new http_version, status_code, status_message, headers, body
    end

    raise "unexpected end of http response"
  end
end
