class HTTP::LogHandler < HTTP::Handler
  def call(request)
    puts "#{request.path} - #{request.headers}"
    call_next(request)
  end
end
