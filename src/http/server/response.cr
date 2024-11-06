require "http/headers"
require "http/status"
require "http/cookie"

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
    def version=(version : String)
      check_headers
      @version = version
    end

    # The status code of this response, which must be set before writing the response
    # body. If not set, the default value is 200 (OK).
    getter status : HTTP::Status

    def status=(status : HTTP::Status)
      check_headers
      @status = status
    end

    # :nodoc:
    property upgrade_handler : (IO ->)?

    @cookies : HTTP::Cookies?

    # :nodoc:
    def initialize(@io : IO, @version = "HTTP/1.1")
      @headers = Headers.new
      @status = :ok
      @wrote_headers = false
      @output = output = @original_output = Output.new(@io)
      output.response = self
    end

    # :nodoc:
    def reset
      # This method is called by RequestProcessor to avoid allocating a new instance for each iteration.
      @headers.clear
      @cookies = nil
      @status = :ok
      @status_message = nil
      @wrote_headers = false
      @output = @original_output
      @original_output.reset
    end

    # Convenience method to set the `Content-Type` header.
    def content_type=(content_type : String)
      check_headers
      headers["Content-Type"] = content_type
    end

    # Convenience method to set the `Content-Length` header.
    def content_length=(content_length : Int)
      check_headers
      headers["Content-Length"] = content_length.to_s
    end

    # Convenience method to retrieve the HTTP status code.
    def status_code : Int32
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
    def cookies : HTTP::Cookies
      @cookies ||= HTTP::Cookies.new
    end

    # :nodoc:
    def read(slice : Bytes) : NoReturn
      raise "Can't read from HTTP::Server::Response"
    end

    # Upgrades this response, writing headers and yielding the connection `IO` (a socket) to the given block.
    # This is useful to implement protocol upgrades, such as websockets.
    def upgrade(&block : IO ->) : Nil
      write_headers
      @upgrade_handler = block
    end

    # Flushes the output. This method must be implemented if wrapping the response output.
    def flush : Nil
      @output.flush
    end

    # Closes this response, writing headers and body if not done yet.
    # This method must be implemented if wrapping the response output.
    def close : Nil
      return if closed?

      @output.close
    end

    # Returns `true` if this response has been closed.
    def closed? : Bool
      @output.closed?
    end

    # Sets the status message.
    def status_message=(status_message : String?)
      check_headers
      @status_message = status_message
    end

    # Returns the status message.
    #
    # Defaults to description of `#status`.
    def status_message : String?
      @status_message || @status.description
    end

    # Sends *status* and *message* as response.
    #
    # This method calls `#reset` to remove any previous settings and writes the
    # given *status* and *message* to the response IO. Finally, it closes the
    # response.
    #
    # If *message* is `nil`, the default message for *status* is used provided
    # by `HTTP::Status#description`.
    #
    # Raises `IO::Error` if the response is closed or headers were already
    # sent.
    def respond_with_status(status : HTTP::Status, message : String? = nil) : Nil
      check_headers
      reset
      @status = status
      @status_message = message ||= @status.description
      self.content_type = "text/plain"
      self << @status.code << ' ' << message << '\n'
      close
    end

    # :ditto:
    def respond_with_status(status : Int, message : String? = nil) : Nil
      respond_with_status(HTTP::Status.new(status), message)
    end

    # Sends a redirect to *location*.
    #
    # The value of *location* gets encoded with `URI.encode`.
    #
    # The *status* determines the HTTP status code which can be
    # `HTTP::Status::FOUND` (`302`) for a temporary redirect or
    # `HTTP::Status::MOVED_PERMANENTLY` (`301`) for a permanent redirect.
    #
    # The response gets closed.
    #
    # Raises `IO::Error` if the response is closed or headers were already
    # sent.
    def redirect(location : String | URI, status : HTTP::Status = :found)
      check_headers

      self.status = status
      headers["Location"] = if location.is_a? URI
                              location.to_s
                            else
                              String.build do |io|
                                URI.encode(location.to_s, io) do |byte|
                                  URI.reserved?(byte) || URI.unreserved?(byte)
                                end
                              end
                            end
      close
    end

    private def check_headers
      raise IO::Error.new "Closed stream" if @original_output.closed?
      if wrote_headers?
        raise IO::Error.new("Headers already sent")
      end
    end

    protected def write_headers
      @io << @version << ' ' << @status.code << ' ' << status_message << "\r\n"
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
        @closed = false
      end

      def reset : Nil
        @in_buffer_rem = Bytes.empty
        @out_count = 0
        @sync = false
        @flush_on_newline = false
        @chunked = false
        @closed = false
      end

      private def unbuffered_read(slice : Bytes) : Int32
        raise "Can't read from HTTP::Server::Response"
      end

      private def unbuffered_write(slice : Bytes) : Nil
        return if slice.empty?

        if response.headers["Transfer-Encoding"]? == "chunked"
          @chunked = true
        elsif !response.wrote_headers?
          if response.version != "HTTP/1.0" && !response.headers.has_key?("Content-Length")
            response.headers["Transfer-Encoding"] = "chunked"
            @chunked = true
          end
        end

        ensure_headers_written

        if @chunked
          slice.size.to_s(@io, 16)
          @io << "\r\n"
          @io.write(slice)
          @io << "\r\n"
        else
          @io.write(slice)
        end
      rescue ex : IO::Error
        unbuffered_close
        raise ClientError.new("Error while writing data to the client", ex)
      end

      def closed? : Bool
        @closed
      end

      def close : Nil
        return if closed?

        # Conditionally determine based on status if the `content-length` header should be added automatically.
        # See https://tools.ietf.org/html/rfc7230#section-3.3.2.
        status = response.status
        set_content_length = !(status.not_modified? || status.no_content? || status.informational?)

        if !response.wrote_headers? && !response.headers.has_key?("Transfer-Encoding") && !response.headers.has_key?("Content-Length") && set_content_length
          response.content_length = @out_count
        end

        ensure_headers_written

        super

        if @chunked
          @io << "0\r\n\r\n"
          @io.flush
        end
      end

      private def ensure_headers_written
        unless response.wrote_headers?
          if response.has_cookies?
            response.cookies.add_response_headers(response.headers)
          end

          response.write_headers
        end
      end

      private def unbuffered_close : Nil
        @closed = true
      end

      private def unbuffered_rewind : Nil
        raise "Can't rewind to HTTP::Server::Response"
      end

      private def unbuffered_flush : Nil
        @io.flush
      rescue ex : IO::Error
        unbuffered_close
        raise ClientError.new("Error while flushing data to the client", ex)
      end
    end
  end

  class ClientError < Exception
  end
end
