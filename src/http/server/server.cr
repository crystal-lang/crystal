require "openssl"
require "socket"
require "./context"
require "./handler"
require "./response"
require "../common"

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

  def self.new(port, &handler : Context ->)
    new("127.0.0.1", port, &handler)
  end

  def self.new(port, handlers : Array(HTTP::Handler), &handler : Context ->)
    new("127.0.0.1", port, handlers, &handler)
  end

  def self.new(port, handlers : Array(HTTP::Handler))
    new("127.0.0.1", port, handlers)
  end

  def self.new(port, handler)
    new("127.0.0.1", port, handler)
  end

  def initialize(@host, @port, &@handler : Context ->)
  end

  def initialize(@host, @port, handlers : Array(HTTP::Handler), &handler : Context ->)
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

  def close
    @wants_close = true
  end

  private def handle_client(sock)
    sock.sync = false
    io = sock
    io = ssl_sock = OpenSSL::SSL::Socket.new(io, :server, @ssl.not_nil!) if @ssl
    must_close = true

    begin
      until @wants_close
        begin
          request = HTTP::Request.from_io(io)
        rescue
          return
        end
        break unless request

        response = Response.new(io)
        response.headers["Connection"] = "keep-alive" if request.keep_alive?
        context = Context.new(request, response)

        @handler.call(context)

        if response.upgraded?
          must_close = false
          return
        end

        response.output.close
        sock.flush

        break unless request.keep_alive?
      end
    ensure
      if must_close
        ssl_sock.try &.close if @ssl
        sock.close
      end
    end
  end

  # Builds all handlers as the middleware for HTTP::Server.
  def self.build_middleware(handlers, last_handler = nil : Context ->)
    raise ArgumentError.new "You must specify at least one HTTP Handler." if handlers.empty?
    0.upto(handlers.size - 2) { |i| handlers[i].next = handlers[i + 1] }
    handlers.last.next = last_handler if last_handler
    handlers.first
  end
end
