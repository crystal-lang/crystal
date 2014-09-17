class HTTP::ErrorHandler < HTTP::Handler
  def call(request)
    begin
      call_next(request)
    rescue ex : Exception
      Response.error("text/plain", "ERROR: #{ex.message}\n#{ex.backtrace.join '\n'}\n")
    end
  end
end
