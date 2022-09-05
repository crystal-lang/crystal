require "./handler"
require "log"

class HTTP::Server::RequestProcessor
  Log = ::Log.for("http.server")

  # Maximum permitted size of the request line in an HTTP request.
  property max_request_line_size = HTTP::MAX_REQUEST_LINE_SIZE

  # Maximum permitted combined size of the headers in an HTTP request.
  property max_headers_size = HTTP::MAX_HEADERS_SIZE

  def initialize(&@handler : HTTP::Handler::HandlerProc)
    @wants_close = false
  end

  def initialize(@handler : HTTP::Handler | HTTP::Handler::HandlerProc)
    @wants_close = false
  end

  def close : Nil
    @wants_close = true
  end

  def process(input, output) : Nil
    response = Response.new(output)

    begin
      until @wants_close
        request = HTTP::Request.from_io(
          input,
          max_request_line_size: max_request_line_size,
          max_headers_size: max_headers_size,
        )

        # EOF
        break unless request

        response.reset

        if request.is_a?(HTTP::Status)
          response.respond_with_status(request)
          return
        end

        response.version = request.version
        response.headers["Connection"] = "keep-alive" if request.keep_alive?
        context = Context.new(request, response)

        Log.with_context do
          @handler.call(context)
        rescue ex : ClientError
          Log.debug(exception: ex.cause) { ex.message }
        rescue ex
          Log.error(exception: ex) { "Unhandled exception on HTTP::Handler" }
          unless response.closed?
            unless response.wrote_headers?
              response.respond_with_status(:internal_server_error)
            end
          end
          return
        ensure
          response.output.close
        end

        output.flush

        # If there is an upgrade handler, hand over
        # the connection to it and return
        if upgrade_handler = response.upgrade_handler
          upgrade_handler.call(output)
          return
        end

        break unless request.keep_alive?

        # Don't continue if the handler set `Connection` header to `close`
        break unless HTTP.keep_alive?(response)

        # The request body is either FixedLengthContent or ChunkedContent.
        # In case it has not entirely been consumed by the handler, the connection is
        # closed the connection even if keep alive was requested.
        case body = request.body
        when FixedLengthContent
          if body.read_remaining > 0
            # Close the connection if there are bytes remaining
            break
          end
        when ChunkedContent
          # Close the connection if the IO has still bytes to read.
          break unless body.closed?
        end
      end
    rescue IO::Error
      # IO-related error, nothing to do
    end
  end
end
