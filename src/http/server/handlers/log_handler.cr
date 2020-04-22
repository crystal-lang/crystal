require "log"

# A handler that logs the request method, resource, status code, and
# the time used to execute the next handler, to the log with source `http.server`.
class HTTP::LogHandler
  include HTTP::Handler
  Log = ::Log.for("http.server")

  @[Deprecated("Use `new` without arguments instead")]
  def initialize(io : IO)
  end

  def initialize
  end

  def call(context)
    start = Time.monotonic

    begin
      call_next(context)
    ensure
      elapsed = Time.monotonic - start
      elapsed_text = elapsed_text(elapsed)

      req = context.request
      res = context.response
      Log.info { "#{req.remote_address || "-"} - #{req.method} #{req.resource} #{req.version} - #{res.status_code} (#{elapsed_text})" }
    end
  end

  private def elapsed_text(elapsed)
    minutes = elapsed.total_minutes
    return "#{minutes.round(2)}m" if minutes >= 1

    "#{elapsed.total_seconds.humanize(precision: 2, significant: false)}s"
  end
end
