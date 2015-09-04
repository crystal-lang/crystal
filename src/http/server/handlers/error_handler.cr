class HTTP::ErrorHandler < HTTP::Handler
  def call(request)
    begin
      call_next(request)
    rescue ex : Exception
      Response.error("text/plain", "ERROR: #{ex.inspect_with_backtrace}\n")
    end
  end
end
