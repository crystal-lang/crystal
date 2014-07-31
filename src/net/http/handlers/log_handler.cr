class HTTP::LogHandler < HTTP::Handler
  def call(request)
    puts "#{request.method} #{request.path} - #{request.headers}"
    call_next(request)
  end
end
