require "log"

class HTTP::Client
  Log = ::Log.for(self)

  def_around_exec do |request|
    emit_log(request)
    yield
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
