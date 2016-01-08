module HTTP
  class Server
    class Context
      getter request
      getter response

      def initialize(@request : Request, @response : Response)
      end
    end

    class Response
      include IO

      getter headers
      property output
      property version
      property status_code
      property status_message

      def initialize(@io)
        @headers = Headers.new
        @version = "HTTP/1.1"
        @status_code = 200
        @status_message = "OK"
        @output = @original_output = output = Output.new(@io)
        output.response = self
      end

      def write_body(string)
        headers["Content-Length"] = string.bytesize.to_s
        @original_output.write_headers
        @output.print(string)
      end

      def write(slice : Slice(UInt8))
        @output.write(slice)
      end

      def read(slice : Slice(UInt8))
        raise "can't read from HTTP::Server::Response"
      end

      def flush
        @output.flush
      end

      def close
        @output.close
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

        delegate headers, response

        def write_headers
          @io << response.version << " " << response.status_code << " " << response.status_message << "\r\n"
          headers.each do |name, values|
            values.each do |value|
              @io << name << ": " << value << "\r\n"
            end
          end
          @io << "\r\n"
          @wrote_headers = true
        end

        private def unbuffered_read(slice : Slice(UInt8))
          raise "can't read from HTTP::Server::Response"
        end

        private def unbuffered_write(slice : Slice(UInt8))
          unless @wrote_headers
            unless headers.has_key?("Content-Length")
              headers["Transfer-Encoding"] = "chunked"
              @chunked = true
            end
            write_headers
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
          unless @wrote_headers
            headers["Content-Length"] = @out_count.to_s
            write_headers
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
end
