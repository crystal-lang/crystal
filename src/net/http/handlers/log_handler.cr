class HTTP::LogHandler < HTTP::Handler
  def call(request)
    call_next(request).tap do |response|
      puts "#{request.method} #{request.path} - #{response.status_code}"
    end
  end
end
