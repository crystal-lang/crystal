require "zlib" ifdef !without_zlib

# A handler that configures an `HTTP::Server::Response` to compress the response
# output, either using gzip or deflate, depending on the `Accept-Encoding` request header.
class HTTP::DeflateHandler < HTTP::Handler
  def call(context)
    ifdef without_zlib
      call_next(context)
    else
      encoding = context.request.headers["Accept-Encoding"]?

      if encoding.try &.includes?("gzip")
        context.response.headers["Content-Encoding"] = "gzip"
        context.response.output = Zlib::Deflate.gzip(context.response.output, sync_close: true)
      elsif encoding.try &.includes?("deflate")
        context.response.headers["Content-Encoding"] = "deflate"
        context.response.output = Zlib::Deflate.new(context.response.output, sync_close: true)
      end

      call_next(context)
    end
  end
end
