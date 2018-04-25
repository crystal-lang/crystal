require "../server"

class HTTP::Server::RequestProcessor
  def initialize(&@handler : HTTP::Handler::Proc)
    @wants_close = false
  end

  def initialize(@handler : HTTP::Handler | HTTP::Handler::Proc)
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

        # Skip request body in case the handler
        # didn't read it all, for the next request
        request.body.try &.close
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
end
