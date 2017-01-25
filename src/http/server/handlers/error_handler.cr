# A handler that invokes the next handler and, if that next handler raises
# an exception, returns with a 500 (Internal Server Error) status code.
#
# In verbose mode prints the exception with its backtrace to the response,
# else a generic error message is returned to the client.
# Use the `HTTP::LogHandler` before this to log the exception on the server side.
class HTTP::ErrorHandler
  include HTTP::Handler

  def initialize(@verbose : Bool = false)
  end

  def call(context)
    begin
      call_next(context)
    rescue ex : Exception
      if @verbose
        context.response.reset
        context.response.status_code = 500
        context.response.content_type = "text/plain"
        context.response.print("ERROR: ")
        ex.inspect_with_backtrace(context.response)
      else
        context.response.respond_with_error
      end
    end
  end
end
