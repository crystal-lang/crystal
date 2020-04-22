# A handler that invokes the next handler and, if that next handler raises
# an exception, returns with a 500 (Internal Server Error) status code.
#
# In verbose mode prints the exception with its backtrace to the response,
# else a generic error message is returned to the client.
# Use the `HTTP::LogHandler` before this to log the exception on the server side.
class HTTP::ErrorHandler
  include HTTP::Handler
  Log = ::Log.for("http.server")

  def initialize(@verbose : Bool = false)
  end

  def call(context)
    begin
      call_next(context)
    rescue ex : HTTP::Server::ClientError
      Log.debug(exception: ex.cause) { ex.message }
    rescue ex : Exception
      Log.error(exception: ex) { "Unhandled exception" }
      unless context.response.closed? || context.response.wrote_headers?
        if @verbose
          context.response.reset
          context.response.status = :internal_server_error
          context.response.content_type = "text/plain"
          context.response.print("ERROR: ")
          context.response.puts(ex.inspect_with_backtrace)
        else
          context.response.respond_with_status(:internal_server_error)
        end
      end
    end
  end
end
