require "openssl"
require "socket"
require "../common"

abstract class HTTP::Handler
  property :next

  def call_next(request)
    if next_handler = @next
      next_handler.call(request)
    else
      HTTP::Response.not_found
    end
  end
end

require "./handlers/*"

# An HTTP::Server
#
# ### Simple Setup
#
# ```
# require "http/server"
#
# server = HTTP::Server.new(8080) do |request|
#   HTTP::Response.ok "text/plain", "Hello world!"
# end
#
# puts "Listening on http://127.0.0.1:8080"
# server.listen
# ```
#
# ### With non-localhost bind address
#
# ```
# require "http/server"
#
# server = HTTP::Server.new("0.0.0.0", 8080) do |request|
#   HTTP::Response.ok "text/plain", "Hello world!"
# end
#
# puts "Listening on http://0.0.0.0:8080"
# server.listen
# ```
#
# ### Add handlers
#
# ```
# require "http/server"
#
# Server.new("127.0.0.1", 8080, [
#   ErrorHandler.new,
#   LogHandler.new,
#   DeflateHandler.new,
#   StaticFileHandler.new("."),
# ]).listen
# ```
#
# ### Add handlers and block
#
# ```
# require "http/server"
#
# server = HTTP::Server.new("0.0.0.0", 8080,
#   [
#     ErrorHandler.new,
#     LogHandler.new,
#   ]) do |request|
#   HTTP::Response.ok "text/plain", "Hello world!"
# end
#
# server.listen
# ```

class HTTP::Server
  property ssl

  @wants_close = false

  def self.new(port, &handler : Request -> Response)
    new("127.0.0.1", port, &handler)
  end

  def self.new(port, handlers : Array(HTTP::Handler), &handler : Request -> Response)
    new("127.0.0.1", port, handlers, &handler)
  end

  def self.new(port, handlers : Array(HTTP::Handler))
    new("127.0.0.1", port, handlers)
  end

  def self.new(port, handler)
    new("127.0.0.1", port, handler)
  end

  def initialize(@host, @port, &@handler : Request -> Response)
  end

  def initialize(@host, @port, handlers : Array(HTTP::Handler), &handler : Request -> Response)
    @handler = HTTP::Server.build_middleware handlers, handler
  end

  def initialize(@host, @port, handlers : Array(HTTP::Handler))
    @handler = HTTP::Server.build_middleware handlers
  end

  def initialize(@host, @port, @handler)
  end

  def listen
    server = TCPServer.new(@host, @port)
    until @wants_close
      spawn handle_client(server.accept)
    end
  end

  def listen_fork(workers = 8)
    server = TCPServer.new(@host, @port)
    workers.times do
      fork do
        loop { spawn handle_client(server.accept) }
      end
    end

    gets
  end

  def close
    @wants_close = true
  end

  private def handle_client(sock)
    sock.sync = false
    io = sock
    io = ssl_sock = OpenSSL::SSL::Socket.new(io, :server, @ssl.not_nil!) if @ssl

    begin
      until @wants_close
        begin
          request = HTTP::Request.from_io(io)
        rescue
          return
        end
        break unless request
        response = @handler.call(request)
        response.headers["Connection"] = "keep-alive" if request.keep_alive?
        response.to_io io
        sock.flush

        if upgrade_handler = response.upgrade_handler
          return upgrade_handler.call(io)
        end

        break unless request.keep_alive?
      end
    ensure
      ssl_sock.try &.close if @ssl
      sock.close
    end
  end

  def self.build_middleware(handlers, last_handler = nil : Request -> Response)
    if handlers.empty?
      raise ArgumentError.new "no handlers specified"
    end

    0.upto(handlers.size - 2) do |i|
      handlers[i].next = handlers[i + 1]
    end

    if last_handler
      handlers.last.next = last_handler
    end

    handlers.first
  end
end
