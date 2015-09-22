require "zlib"

class HTTP::DeflateHandler < HTTP::Handler
  DEFLATE_TYPES = %w(text/html text/plain text/xml text/css text/javascript application/javascript)

  def call(request)
    response = call_next(request)

    if should_deflate?(request, response)
      body_io = if response.body?
        StringIO.new(response.body)
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
    accept_encoding = request.headers["Accept-encoding"]?
    content_type = response.headers["Content-Type"]?
    accept_encoding && accept_encoding =~ /deflate/ && response.version == "HTTP/1.1" && content_type && DEFLATE_TYPES.includes?(content_type)
  end
end
