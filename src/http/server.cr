{% if !flag?(:without_openssl) %}
  require "openssl"
{% end %}
require "socket"
require "./server/context"
require "./server/handler"
require "./server/response"
require "./common"

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
# in a subsequent handler and return a 500 status code (see `HTTP::ErrorHandler`),
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
# HTTP::Server.new("127.0.0.1", 8080, [
#   HTTP::ErrorHandler.new,
#   HTTP::LogHandler.new,
#   HTTP::CompressHandler.new,
#   HTTP::StaticFileHandler.new("."),
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
#     HTTP::ErrorHandler.new,
#     HTTP::LogHandler.new,
#   ]) do |context|
#   context.response.content_type = "text/plain"
#   context.response.print "Hello world!"
# end
#
# server.listen
# ```
class HTTP::Server
  {% if !flag?(:without_openssl) %}
    property tls : OpenSSL::SSL::Context::Server?
  {% end %}

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

  def initialize(@host : String, @port : Int32, &handler : Context ->)
    @processor = RequestProcessor.new(handler)
  end

  def initialize(@host : String, @port : Int32, handlers : Array(HTTP::Handler), &handler : Context ->)
    handler = HTTP::Server.build_middleware handlers, handler
    @processor = RequestProcessor.new(handler)
  end

  def initialize(@host : String, @port : Int32, handlers : Array(HTTP::Handler))
    handler = HTTP::Server.build_middleware handlers
    @processor = RequestProcessor.new(handler)
  end

  def initialize(@host : String, @port : Int32, handler : HTTP::Handler | HTTP::Handler::Proc)
    @processor = RequestProcessor.new(handler)
  end

  # Returns the TCP port the server is connected to.
  #
  # For example you may let the system choose a port, then report it:
  # ```
  # server = HTTP::Server.new(0) { }
  # server.bind
  # server.port # => 12345
  # ```
  def port
    if server = @server
      server.local_address.port.to_i
    else
      @port
    end
  end

  # Creates the underlying `TCPServer` if the doesn't already exist.
  #
  # You may set *reuse_port* to true to enable the `SO_REUSEPORT` socket option,
  # which allows multiple processes to bind to the same port.
  def bind(reuse_port = false)
    @server ||= TCPServer.new(@host, @port, reuse_port: reuse_port)
  end

  # Starts the server. Blocks until the server is closed.
  #
  # See `#bind` for details on the *reuse_port* argument.
  def listen(reuse_port = false)
    server = bind(reuse_port)
    until @wants_close
      spawn handle_client(server.accept?)
    end
  end

  # Gracefully terminates the server. It will process currently accepted
  # requests, but it won't accept new connections.
  def close
    @wants_close = true
    @processor.close
    if server = @server
      server.close
      @server = nil
    end
  end

  private def handle_client(io)
    # nil means the server was closed
    return unless io

    io.sync = false

    {% if !flag?(:without_openssl) %}
      if tls = @tls
        io = OpenSSL::SSL::Socket::Server.new(io, tls, sync_close: true)
      end
    {% end %}

    @processor.process(io, io)
  end

  # Builds all handlers as the middleware for `HTTP::Server`.
  def self.build_middleware(handlers, last_handler : (Context ->)? = nil)
    raise ArgumentError.new "You must specify at least one HTTP Handler." if handlers.empty?
    0.upto(handlers.size - 2) { |i| handlers[i].next = handlers[i + 1] }
    handlers.last.next = last_handler if last_handler
    handlers.first
  end
end
