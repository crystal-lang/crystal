require "log"

# A handler that logs the request method, resource, status code, and
# the time used to execute the next handler
class HTTP::LogHandler
  include HTTP::Handler

  @[Deprecated("Use `new([Log])` instead")]
  def initialize(io : IO)
    @log = Log.new("http.server", Log::IOBackend.new(io), :info)
  end

  def initialize(@log = Log.for("http.server"))
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

      addr =
        {% begin %}
        case remote_address = req.remote_address
        when nil
          "-"
        {% unless flag?(:win32) %}
        when Socket::IPAddress
          remote_address.address
        {% end %}
        else
          remote_address
        end
        {% end %}

      @log.info { "#{addr} - #{req.method} #{req.resource} #{req.version} - #{res.status_code} (#{elapsed_text})" }
    end
  end

  private def elapsed_text(elapsed)
    minutes = elapsed.total_minutes
    return "#{minutes.round(2)}m" if minutes >= 1

    "#{elapsed.total_seconds.humanize(precision: 2, significant: false)}s"
  end
end
