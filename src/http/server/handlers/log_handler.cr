# A handler that logs the request method, resource, status code, and
# the time used to execute the next handler, to the log with source `http.server`.
class HTTP::LogHandler
  include HTTP::Handler
  Log = HTTP::Server::Log

  @[Deprecated("Use `new` without arguments instead")]
  def initialize(io : IO)
  end

  def initialize
  end

  def call(context)
    elapsed = Time.measure { call_next(context) }
    elapsed_text = elapsed_text(elapsed)

    Log.info { "#{context.request.method} #{context.request.resource} - #{context.response.status_code} (#{elapsed_text})" }
  rescue e
    unless context.response.closed?
      Log.error(exception: e) { "#{context.request.method} #{context.request.resource} - Unhandled exception:" }
    end
    raise e
  end

  private def elapsed_text(elapsed)
    minutes = elapsed.total_minutes
    return "#{minutes.round(2)}m" if minutes >= 1

    "#{elapsed.total_seconds.humanize(precision: 2, significant: false)}s"
  end
end
