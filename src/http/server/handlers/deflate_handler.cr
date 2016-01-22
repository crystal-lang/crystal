require "zlib"

class HTTP::DeflateHandler < HTTP::Handler
  def call(context)
    encoding = context.request.headers["Accept-Encoding"]?

    if encoding.try &.includes?("gzip")
      context.response.headers["Content-Encoding"] = "gzip"
      context.response.output = Zlib::Deflate.gzip(context.response.output)
    elsif encoding.try &.includes?("deflate")
      context.response.headers["Content-Encoding"] = "deflate"
      context.response.output = Zlib::Deflate.new(context.response.output)
    end

    call_next(context)
  end
end
