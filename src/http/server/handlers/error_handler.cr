# A handler that invokes the next handler and, if that next handler raises
# an exception, returns with a 500 (Internal Server Error) status code and
# prints the exception with its backtrace to the response's body.
class HTTP::ErrorHandler < HTTP::Handler
  def call(context)
    begin
      call_next(context)
    rescue ex : Exception
      context.response.status_code = 500
      context.response.content_type = "text/plain"
      context.response.print("ERROR: ")
      ex.inspect_with_backtrace(context.response)
    end
  end
end
