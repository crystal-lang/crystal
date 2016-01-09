class HTTP::Server
  class Response
    include IO

    getter headers
    property output
    property version
    property status_code

    def initialize(@io)
      @headers = Headers.new
      @version = "HTTP/1.1"
      @status_code = 200
      @wrote_headers = false
      @upgraded = false
      @output = output = Output.new(@io)
      output.response = self
    end

    def content_type=(content_type : String)
      headers["Content-Type"] = content_type
    end

    def content_length=(content_length : Int)
      headers["Content-Length"] = content_length.to_s
    end

    def write(slice : Slice(UInt8))
      @output.write(slice)
    end

    def read(slice : Slice(UInt8))
      raise "can't read from HTTP::Server::Response"
    end

    def upgrade
      @upgraded = true
      write_headers
      flush
      yield @io
    end

    def upgraded?
      @upgraded
    end

    def flush
      @output.flush
    end

    def close
      @output.close
    end

    protected def write_headers
      status_message = HTTP::Response.default_status_message_for(@status_code)
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

      private def unbuffered_read(slice : Slice(UInt8))
        raise "can't read from HTTP::Server::Response"
      end

      private def unbuffered_write(slice : Slice(UInt8))
        unless response.wrote_headers?
          unless response.headers.has_key?("Content-Length")
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
