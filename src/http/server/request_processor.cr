require "../server"

class HTTP::Server::RequestProcessor
  def initialize(&@handler : HTTP::Handler::HandlerProc)
    @wants_close = false
  end

  def initialize(@handler : HTTP::Handler | HTTP::Handler::HandlerProc)
    @wants_close = false
  end

  def close
    @wants_close = true
  end

  def process(input, output, error = STDERR)
    must_close = true
    response = Response.new(output)

    begin
      until @wants_close
        request = HTTP::Request.from_io(input)

        # EOF
        break unless request

        if request.is_a?(HTTP::Request::BadRequest)
          response.respond_with_error("Bad Request", 400)
          response.close
          return
        end

        response.version = request.version
        response.reset
        response.headers["Connection"] = "keep-alive" if request.keep_alive?
        context = Context.new(request, response)

        begin
          @handler.call(context)
        rescue ex
          response.respond_with_error
          response.close
          error.puts "Unhandled exception on HTTP::Handler"
          ex.inspect_with_backtrace(error)
          return
        end

        if response.upgraded?
          must_close = false
          return
        end

        response.output.close
        output.flush

        break unless request.keep_alive?

        # Don't continue if the handler set `Connection` header to `close`
        break unless HTTP.keep_alive?(response)

        # The request body is either FixedLengthContent or ChunkedContent.
        # In case it has not entirely been consumed by the handler, try to
        # skip to the end. If the request is larger than maxmum skippable size,
        # we close the connection even if keep alive was requested.
        case body = request.body
        when FixedLengthContent
          if body.read_remaining > 16_384
            # Close the connection if remaining length exceeds the maximum skipable size.
            break
          else
            body.skip_to_end
          end
        when ChunkedContent
          # Try to read maximum skipable number of bytes.
          # Close the connection if the IO has still more to read.
          break unless skip_to_end(body)
        end
      end
    rescue ex : Errno
      # IO-related error, nothing to do
    ensure
      begin
        input.close if must_close
      rescue ex : Errno
        # IO-related error, nothing to do
      end
    end
  end

  # Reads and discards bytes from `io` until there are no more bytes.
  # If there are more than 16_384 bytes to be read from the IO, it returns `false`.
  private def skip_to_end(io : IO) : Bool
    buffer = uninitialized UInt8[4096]

    4.times do
      return true if io.read(buffer.to_slice) < 4096
    end

    false
  end
end
