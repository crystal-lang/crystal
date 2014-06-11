class HTTP::LogHandler < HTTP::Handler
  def call(request)
    puts "#{request.path} - #{request.headers}"
    @next.not_nil!.call request
  end
end
