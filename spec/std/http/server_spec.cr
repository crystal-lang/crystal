require "http/server"

module HTTP
  typeof(begin
    server = Server.new(8080) { |req| Response.ok("text/plain", "OK") }
    server.listen
    server.listen_fork(workers: 2)
    server.close

    Server.new(8080, [
        ErrorHandler.new,
        LogHandler.new,
        StaticFileHandler.new("."),
      ]
      ).listen
  end)
end
