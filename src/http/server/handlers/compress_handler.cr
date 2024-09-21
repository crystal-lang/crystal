{% if !flag?(:without_zlib) %}
  require "compress/deflate"
  require "compress/gzip"
{% end %}

# A handler that configures an `HTTP::Server::Response` to compress the response
# output, either using gzip or deflate, depending on the `Accept-Encoding` request header.
#
# NOTE: To use `CompressHandler`, you must explicitly import it with `require "http"`
class HTTP::CompressHandler
  include HTTP::Handler

  def call(context)
    {% if flag?(:without_zlib) %}
      call_next(context)
    {% else %}
      context.response.output = CompressIO.new(context.response.output, context)
      call_next(context)
    {% end %}
  end

  {% unless flag?(:without_zlib) %}
    private class CompressIO < IO
      def initialize(@io : IO, @context : HTTP::Server::Context)
        @checked = false
      end

      def read(slice : Bytes)
        raise NotImplementedError.new("read")
      end

      def write(slice : Bytes) : Nil
        check_output unless @checked
        @io.write(slice)
      end

      def flush
        @io.flush
      end

      def close
        @io.close
      end

      private def check_output
        @checked = true

        return if @context.response.wrote_headers?
        return if @context.response.headers.has_key?("Content-Encoding")

        request_headers = @context.request.headers

        if request_headers.includes_word?("Accept-Encoding", "gzip")
          @context.response.headers["Content-Encoding"] = "gzip"
          @context.response.headers.delete("Content-Length")
          @io = Compress::Gzip::Writer.new(@io, sync_close: true)
        elsif request_headers.includes_word?("Accept-Encoding", "deflate")
          @context.response.headers["Content-Encoding"] = "deflate"
          @context.response.headers.delete("Content-Length")
          @io = Compress::Deflate::Writer.new(@io, sync_close: true)
        end
      end
    end
  {% end %}
end
