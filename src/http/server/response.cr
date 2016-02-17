class HTTP::Server
  # The response to configure and write to in an `HTTP::Server` handler.
  #
  # The response `status_code` and `headers` must be configured before writing
  # the response body. Once response output is written, changing the `status`
  # and `headers` properties has no effect.
  #
  # The `HTTP::Server::Response` is a write-only `IO`, so all `IO` methods are available
  # in it.
  #
  # A response can be upgraded with the `upgrade` method. Once invoked, headers
  # are written and the connection `IO` (a socket) is yielded to the given block.
  # The block must invoke `close` afterwards, the server won't do it in this case.
  # This is useful to implement protocol upgrades, such as websockets.
  class Response
    include IO

    # The response headers (`HTTP::Headers`). These must be set before writing to the response.
    getter headers

    # The version of the HTTP::Request that created this response.
    getter version

    # The `IO` to which output is written. This can be changed/wrapped to filter
    # the response body (for example to compress the output).
    property output

    # :nodoc:
    setter version

    # The status code of this response, which must be set before writing the response
    # body. If not set, the default value is 200 (OK).
    property status_code

    # :nodoc:
    def initialize(@io, @version = "HTTP/1.1")
      @headers = Headers.new
      @status_code = 200
      @wrote_headers = false
      @upgraded = false
      @output = @original_output = output = Output.new(@io)
      output.response = self
    end

    # :nodoc:
    def reset
      @headers.clear
      @status_code = 200
      @wrote_headers = false
      @upgraded = false
      @output = @original_output
      @original_output.reset
    end

    # Convenience method to set the `Content-Type` header.
    def content_type=(content_type : String)
      headers["Content-Type"] = content_type
    end

    # Convenience method to set the `Content-Length` header.
    def content_length=(content_length : Int)
      headers["Content-Length"] = content_length.to_s
    end

    # See `IO#write(slice)`.
    def write(slice : Slice(UInt8))
      @output.write(slice)
    end

    # :nodoc:
    def read(slice : Slice(UInt8))
      raise "can't read from HTTP::Server::Response"
    end

    # Upgrades this response, writing headers and yieling the connection `IO` (a socket) to the given block.
    # The block must invoke `close` afterwards, the server won't do it in this case.
    # This is useful to implement protocol upgrades, such as websockets.
    def upgrade
      @upgraded = true
      write_headers
      flush
      yield @io
    end

    # :nodoc:
    def upgraded?
      @upgraded
    end

    # Flushes the output. This method must be implemented if wrapping the response output.
    def flush
      @output.flush
    end

    # Closes this response, writing headers and body if not done yet.
    # This method must be implemented if wrapping the response output.
    def close
      @output.close
    end

    protected def write_headers
      status_message = HTTP.default_status_message_for(@status_code)
      @io << @version << " " << @status_code << " " << status_message << "\r\n"
      headers.each do |name, values|
        values.each do |value|
          @io << name << ": " << value << "\r\n"
        end
      end
      @io << "\r\n"
      @wrote_headers = true
    end

    protected def wrote_headers?
      @wrote_headers
    end

    # :nodoc:
    class Output
      include IO::Buffered

      property! response

      def initialize(@io)
        @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
        @out_count = 0
        @sync = false
        @flush_on_newline = false
        @chunked = false
      end

      def reset
        @in_buffer_rem = Slice.new(Pointer(UInt8).null, 0)
        @out_count = 0
        @sync = false
        @flush_on_newline = false
        @chunked = false
      end

      private def unbuffered_read(slice : Slice(UInt8))
        raise "can't read from HTTP::Server::Response"
      end

      private def unbuffered_write(slice : Slice(UInt8))
        unless response.wrote_headers?
          if response.version != "HTTP/1.0" && !response.headers.has_key?("Content-Length")
            response.headers["Transfer-Encoding"] = "chunked"
            @chunked = true
          end
          response.write_headers
        end

        if @chunked
          slice.size.to_s(16, @io)
          @io << "\r\n"
          @io.write(slice)
          @io << "\r\n"
        else
          @io.write(slice)
        end
      end

      def close
        unless response.wrote_headers?
          response.content_length = @out_count
          response.write_headers
        end
        super
      end

      private def unbuffered_close
        @io << "0\r\n\r\n" if @chunked
      end

      private def unbuffered_rewind
        raise "can't rewind to HTTP::Server::Response"
      end

      private def unbuffered_flush
        @io.flush
      end
    end
  end
end
