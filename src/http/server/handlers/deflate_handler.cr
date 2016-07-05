{% if !flag?(:without_zlib) %}
  require "zlib"
{% end %}

# A handler that configures an `HTTP::Server::Response` to compress the response
# output, either using gzip or deflate, depending on the `Accept-Encoding` request header.
class HTTP::DeflateHandler < HTTP::Handler
  def call(context)
    {% if flag?(:without_zlib) %}
      call_next(context)
    {% else %}
      request_headers = context.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        context.response.headers["Content-Encoding"] = "gzip"
        context.response.output = Zlib::Deflate.gzip(context.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        context.response.headers["Content-Encoding"] = "deflate"
        context.response.output = Zlib::Deflate.new(context.response.output, sync_close: true)
      end

      call_next(context)
    {% end %}
  end
end
