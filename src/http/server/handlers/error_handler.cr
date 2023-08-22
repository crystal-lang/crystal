# A handler that invokes the next handler and, if that next handler raises
# an exception, returns with a 500 (Internal Server Error) status code.
#
# In verbose mode prints the exception with its backtrace to the response.
# Otherwise a generic error message is returned to the client.
#
# This handler also logs the exceptions to the specified logger or
# the logger for the source "http.server" by default.
#
# NOTE: To use `ErrorHandler`, you must explicitly import it with `require "http"`
class HTTP::ErrorHandler
  include HTTP::Handler

  def initialize(@verbose : Bool = false, @log = Log.for("http.server"))
  end

  def call(context) : Nil
    call_next(context)
  rescue ex : HTTP::Server::ClientError
    @log.debug(exception: ex.cause) { ex.message }
  rescue ex : Exception
    @log.error(exception: ex) { "Unhandled exception" }
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
