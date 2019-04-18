# A handler that logs the request method, resource, status code, and
# the time used to execute the next handler, to the given `IO`.
class HTTP::LogHandler
  include HTTP::Handler

  # Initializes this handler to log to the given `IO`.
  def initialize(@io : IO = STDOUT)
  end

  def call(context)
    elapsed = Time.measure { call_next(context) }
    elapsed_text = elapsed_text(elapsed)

    @io.puts "#{context.request.method} #{context.request.resource} - #{context.response.status_code} (#{elapsed_text})"
  rescue e
    @io.puts "#{context.request.method} #{context.request.resource} - Unhandled exception:"
    e.inspect_with_backtrace(@io)
    raise e
  end

  private def elapsed_text(elapsed)
    minutes = elapsed.total_minutes
    return "#{minutes.round(2)}m" if minutes >= 1

    "#{elapsed.total_seconds.humanize(precision: 2, significant: false)}s"
  end
end
