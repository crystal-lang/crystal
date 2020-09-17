require "log"

class HTTP::Client
  Log = ::Log.for(self)

  protected def before_exec(request)
    previous_def
    emit_log(request)
  end

  protected def emit_log(request)
    Log.debug &.emit("Performing request",
      method: request.method,
      host: host,
      port: port,
      resource: request.resource,
    )
  end
end
