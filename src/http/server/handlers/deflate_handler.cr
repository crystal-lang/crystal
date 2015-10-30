require "zlib"

class HTTP::DeflateHandler < HTTP::Handler
  DEFAULT_DEFLATE_TYPES = %w(text/html text/plain text/xml text/css text/javascript application/javascript application/json)

  property deflate_types

  def initialize(@deflate_types = DEFAULT_DEFLATE_TYPES)
  end

  def call(request)
    response = call_next(request)

    if should_deflate?(request, response)
      body_io = if response.body?
                  MemoryIO.new(response.body)
                else
                  response.body_io
                end

      deflate_io = Zlib::Deflate.new(body_io)

      headers = response.headers.dup
      headers.delete "Content-length"
      headers["Content-Encoding"] = "deflate"

      response = Response.new(response.status_code, nil, headers, response.status_message, response.version, deflate_io)
    end

    response
  end

  private def should_deflate?(request, response)
    return false unless HTTP::Response.mandatory_body?(response.status_code)
    return false if response.headers["Cache-Control"]? =~ /\bno-transform\b/

    accept_encoding = request.headers["Accept-encoding"]?
    content_type = response.content_type
    accept_encoding && accept_encoding =~ /deflate/ && response.version == "HTTP/1.1" && content_type && deflate_types.includes?(content_type)
  end
end
