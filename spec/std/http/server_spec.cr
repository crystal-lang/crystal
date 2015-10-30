require "http/server"

module HTTP
  typeof(begin
    # Initialize with custom host
    server = Server.new("0.0.0.0", 0) { |req| HTTP::Response.ok("text/plain", "OK") }
    server.listen
    server.listen_fork(workers: 2)
    server.close

    server = Server.new("0.0.0.0", 0, [
      ErrorHandler.new,
      LogHandler.new,
      DeflateHandler.new,
      StaticFileHandler.new("."),
    ]
    )
    server.listen
    server.close

    server = Server.new("0.0.0.0", 0, [StaticFileHandler.new(".")]) { |req| HTTP::Response.ok("text/plain", "OK") }
    server.listen
    server.close

    # Initialize with default host
    server = Server.new(0) { |req| HTTP::Response.ok("text/plain", "OK") }
    server.listen
    server.listen_fork(workers: 2)
    server.close

    server = Server.new(0, [
      ErrorHandler.new,
      LogHandler.new,
      DeflateHandler.new,
      StaticFileHandler.new("."),
    ]
    )
    server.listen
    server.close

    server = Server.new(0, [StaticFileHandler.new(".")]) { |req| HTTP::Response.ok("text/plain", "OK") }
    server.listen
    server.close
  end)
end
