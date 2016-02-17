require "./client"
require "../common"

class HTTP::Client::Response
  getter version
  getter status_code
  getter status_message
  getter headers
  getter! body_io
  property upgrade_handler

  def initialize(@status_code, @body = nil, @headers = Headers.new : Headers, status_message = nil, @version = "HTTP/1.1", @body_io = nil)
    @status_message = status_message || HTTP.default_status_message_for(@status_code)

    if Response.mandatory_body?(@status_code)
      @body = "" unless @body || @body_io
    else
      if @body || @body_io
        raise ArgumentError.new("status #{status_code} should not have a body")
      end
    end
  end

  def body
    @body || ""
  end

  def body?
    @body
  end

  # Returns a convenience wrapper around querying and setting cookie related
  # headers, see `HTTP::Cookies`.
  def cookies
    @cookies ||= Cookies.from_headers(headers)
  end

  def keep_alive?
    HTTP.keep_alive?(self)
  end

  def content_type
    process_content_type_header.content_type
  end

  def charset
    process_content_type_header.charset
  end

  private def process_content_type_header
    @computed_content_type_header ||= begin
      HTTP.content_type_and_charset(headers)
    end
  end

  def to_io(io)
    io << @version << " " << @status_code << " " << @status_message << "\r\n"
    cookies = @cookies
    headers = cookies ? cookies.add_response_headers(@headers) : @headers
    HTTP.serialize_headers_and_body(io, headers, @body || @body_io, @version)
  end

  # :nodoc:
  def consume_body_io
    if io = @body_io
      @body = io.gets_to_end
      @body_io = nil
    end
  end

  def self.mandatory_body?(status_code)
    !(status_code / 100 == 1 || status_code == 204 || status_code == 304)
  end

  def self.supports_chunked?(version)
    version == "HTTP/1.1"
  end

  def self.from_io(io, ignore_body = false, decompress = true)
    from_io(io, ignore_body: ignore_body, decompress: decompress) do |response|
      response.consume_body_io
      return response
    end
  end

  def self.from_io(io, ignore_body = false, decompress = true, &block)
    line = io.gets
    if line
      pieces = line.split(3)
      http_version = pieces[0]
      status_code = pieces[1].to_i
      status_message = pieces[2]? ? pieces[2].chomp : ""

      body_type = HTTP::BodyType::OnDemand
      body_type = HTTP::BodyType::Mandatory if mandatory_body?(status_code)
      body_type = HTTP::BodyType::Prohibited if ignore_body

      HTTP.parse_headers_and_body(io, body_type: body_type, decompress: decompress) do |headers, body|
        return yield new status_code, nil, headers, status_message, http_version, body
      end
    end

    raise "unexpected end of http response"
  end
end
