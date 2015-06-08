class HTTP::LogHandler < HTTP::Handler
  def call(request)
    time = Time.now
    response = call_next(request)
    elapsed = Time.now - time
    elapsed_text = elapsed_text(elapsed)

    puts "#{request.method} #{request.path} - #{response.status_code} (#{elapsed_text})"
    response
  end

  private def elapsed_text(elapsed)
    minutes = elapsed.total_minutes
    return "#{minutes.round(2)}m" if minutes >= 1

    seconds = elapsed.total_seconds
    return "#{seconds.round(2)}s" if seconds >= 1

    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}ns"
  end
end
