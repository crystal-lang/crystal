require "openssl" ifdef !without_openssl
require "socket"
require "./context"
require "./handler"
require "./response"
require "../common"

# An HTTP server.
#
# A server is given a handler that receives an `HTTP::Server::Context` that holds
# the `HTTP::Request` to process and must in turn configure and write to an `HTTP::Server::Response`.
#
# The `HTTP::Server::Response` object has `status` and `headers` properties that can be
# configured before writing the response body. Once response output is written,
# changing the `status` and `headers` properties has no effect.
#
# The `HTTP::Server::Response` is also a write-only `IO`, so all `IO` methods are available
# in it.
#
# The handler given to a server can simply be a block that receives an `HTTP::Server::Context`,
# or it can be an `HTTP::Handler`. An `HTTP::Handler` has an optional `next` handler,
# so handlers can be chained. For example, an initial handler may handle exceptions
# in a subsequent handler and return a 500 staus code (see `HTTP::ErrorHandler`),
# the next handler might log the incoming request (see `HTTP::LogHandler`), and
# the final handler deals with routing and application logic.
#
# ### Simple Setup
#
# A handler is given with a block.
#
# ```
# require "http/server"
#
# server = HTTP::Server.new(8080) do |context|
#   context.response.content_type = "text/plain"
#   context.response.print "Hello world!"
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
# server = HTTP::Server.new("0.0.0.0", 8080) do |context|
#   context.response.content_type = "text/plain"
#   context.response.print "Hello world!"
# end
#
# puts "Listening on http://0.0.0.0:8080"
# server.listen
# ```
#
# ### Add handlers
#
# A series of handlers are chained.
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
# A series of handlers is chained, the last one being the given block.
#
# ```
# require "http/server"
#
# server = HTTP::Server.new("0.0.0.0", 8080,
#   [
#     ErrorHandler.new,
#     LogHandler.new,
#   ]) do |context|
#   context.response.content_type = "text/plain"
#   context.response.print "Hello world!"
# end
#
# server.listen
# ```
class HTTP::Server
  ifdef !without_openssl
    property ssl : OpenSSL::SSL::Context?
  end

  @wants_close : Bool
  @wants_close = false
  @host : String
  @port : Int32

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

  private def handle_client(io)
    io.sync = false

    ifdef !without_openssl
      if ssl = @ssl
        io = OpenSSL::SSL::Socket.new(io, :server, ssl, sync_close: true)
      end
    end

    must_close = true
    response = Response.new(io)

    begin
      until @wants_close
        begin
          request = HTTP::Request.from_io(io)
        rescue
          return
        end
        break unless request

        response.version = request.version
        response.reset
        response.headers["Connection"] = "keep-alive" if request.keep_alive?
        context = Context.new(request, response)

        @handler.call(context)

        if response.upgraded?
          must_close = false
          return
        end

        response.output.close
        io.flush

        break unless request.keep_alive?
      end
    ensure
      io.close if must_close
    end
  end

  # Builds all handlers as the middleware for HTTP::Server.
  def self.build_middleware(handlers, last_handler : Context -> = nil)
    raise ArgumentError.new "You must specify at least one HTTP Handler." if handlers.empty?
    0.upto(handlers.size - 2) { |i| handlers[i].next = handlers[i + 1] }
    handlers.last.next = last_handler if last_handler
    handlers.first
  end
end
