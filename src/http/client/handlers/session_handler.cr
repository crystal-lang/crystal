class HTTP::SessionHandler < HTTP::Client::Handler
  def initialize(@cookie_jar : HTTP::Cookies = HTTP::Cookies.new)
  end

  def call(request : HTTP::Request)
    @cookie_jar.add_request_headers(request.headers)
    call_next(request)
  end

  def call(response : HTTP::Client::Response)
    @cookie_jar.fill_from_headers(response.headers)
    call_next(response)
  end
end
