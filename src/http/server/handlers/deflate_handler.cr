require "zlib"

class HTTP::DeflateHandler < HTTP::Handler
  def call(context)
    if context.request.headers["Accept-Encoding"]?.try &.includes?("deflate")
      context.response.headers["Content-Encoding"] = "deflate"
      context.response.output = Zlib::Deflate.new(context.response.output)
    end

    call_next(context)
  end
end
