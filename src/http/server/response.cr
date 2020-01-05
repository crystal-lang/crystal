class HTTP::Server
  # The response to configure and write to in an `HTTP::Server` handler.
  #
  # The response `status` and `headers` must be configured before writing
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
  class Response < IO
    # The response headers (`HTTP::Headers`). These must be set before writing to the response.
    getter headers : HTTP::Headers

    # The version of the HTTP::Request that created this response.
    getter version : String

    # The `IO` to which output is written. This can be changed/wrapped to filter
    # the response body (for example to compress the output).
    property output : IO

    # :nodoc:
    setter version : String

    # The status code of this response, which must be set before writing the response
    # body. If not set, the default value is 200 (OK).
    property status : HTTP::Status

    # :nodoc:
    def initialize(@io : IO, @version = "HTTP/1.1")
      @headers = Headers.new
      @status = :ok
      @wrote_headers = false
      @upgraded = false
      @output = output = @original_output = Output.new(@io)
      output.response = self
    end

    # :nodoc:
    def reset
      # This method is called by RequestProcessor to avoid allocating a new instance for each iteration.
      @headers.clear
      @cookies = nil
      @status = :ok
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

    # Convenience method to retrieve the HTTP status code.
    def status_code
      status.code
    end

    # Convenience method to set the HTTP status code.
    def status_code=(status_code : Int32)
      self.status = HTTP::Status.new(status_code)
      status_code
    end

    # See `IO#write(slice)`.
    def write(slice : Bytes) : Nil
      return if slice.empty?

      @output.write(slice)
    end

    # Convenience method to set cookies, see `HTTP::Cookies`.
    def cookies
      @cookies ||= HTTP::Cookies.new
    end

    # :nodoc:
    def read(slice : Bytes)
      raise "Can't read from HTTP::Server::Response"
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
      return if closed?

      @output.close
    end

    # Returns `true` if this response has been closed.
    def closed?
      @output.closed?
    end

    @status_message : String?

    # Sends *status* and *message* as response.
    #
    # This method calls `#reset` to remove any previous settings and writes the
    # given *status* and *message* to the response IO. Finally, it closes the
    # response.
    #
    # If *message* is `nil`, the default message for *status* is used provided
    # by `HTTP::Status#description`.
    def respond_with_status(status : HTTP::Status, message : String? = nil)
      reset
      @status = status
      @status_message = message ||= @status.description
      self.content_type = "text/plain"
      self << @status.code << ' ' << message << '\n'
      close
    end

    # :ditto:
    def respond_with_status(status : Int, message : String? = nil)
      respond_with_status(HTTP::Status.new(status), message)
    end

    protected def write_headers
      @io << @version << ' ' << @status.code << ' ' << (@status_message || @status.description) << "\r\n"
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

    protected def has_cookies?
      !@cookies.nil?
    end

    # :nodoc:
    class Output < IO
      include IO::Buffered

      property! response : Response

      @chunked : Bool
      @io : IO

      def initialize(@io)
        @chunked = false
      end

      def reset
        @in_buffer_rem = Bytes.empty
        @out_count = 0
        @sync = false
        @chunked = false
        @closed = false
      end

      private def unbuffered_read(slice : Bytes)
        raise "Can't read from HTTP::Server::Response"
      end

      private def unbuffered_write(slice : Bytes)
        return if slice.empty?

        unless response.wrote_headers?
          if response.version != "HTTP/1.0" && !response.headers.has_key?("Content-Length")
            response.headers["Transfer-Encoding"] = "chunked"
            @chunked = true
          end
        end

        ensure_headers_written

        if @chunked
          slice.size.to_s(16, @io)
          @io << "\r\n"
          @io.write(slice)
          @io << "\r\n"
        else
          @io.write(slice)
        end
      end

      def closed?
        @closed
      end

      def close
        return if closed?

        unless response.wrote_headers?
          response.content_length = @out_count
        end

        ensure_headers_written

        super
      end

      private def ensure_headers_written
        unless response.wrote_headers?
          if response.has_cookies?
            response.cookies.add_response_headers(response.headers)
          end

          response.write_headers
        end
      end

      private def unbuffered_close
        @io << "0\r\n\r\n" if @chunked
        @closed = true
      end

      private def unbuffered_rewind
        raise "Can't rewind to HTTP::Server::Response"
      end

      private def unbuffered_flush
        @io.flush
      end
    end
  end
end
