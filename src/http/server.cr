require "socket"
require "uri"
require "../network_server"
require "./server/context"
require "./server/handler"
require "./server/response"
require "./server/request_processor"
require "./common"
require "log"
{% unless flag?(:without_openssl) %}
  require "openssl"
{% end %}

# A concurrent HTTP server implementation.
#
# A server is initialized with a handler chain responsible for processing each
# incoming request.
#
# ```
# require "http/server"
#
# server = HTTP::Server.new do |context|
#   context.response.content_type = "text/plain"
#   context.response.print "Hello world!"
# end
#
# address = server.bind_tcp 8080
# puts "Listening on http://#{address}"
# server.listen
# ```
#
# ## Request processing
#
# The handler chain receives an instance of `HTTP::Server::Context` that holds
# the `HTTP::Request` to process and a `HTTP::Server::Response` which it can
# configure and write to.
#
# Each connection is processed concurrently in a separate `Fiber` and can handle
# multiple subsequent requests-response cycles with connection keep-alive.
#
# ### Handler chain
#
# The handler given to a server can simply be a block that receives an `HTTP::Server::Context`,
# or it can be an instance of `HTTP::Handler`. An `HTTP::Handler` has a `#next`
# method to forward processing to the next handler in the chain.
#
# For example, an initial handler might handle exceptions raised from subsequent
# handlers and return a `500 Server Error` status (see `HTTP::ErrorHandler`).
# The next handler might log all incoming requests (see `HTTP::LogHandler`).
# And the final handler deals with routing and application logic.
#
# ```
# require "http/server"
#
# server = HTTP::Server.new([
#   HTTP::ErrorHandler.new,
#   HTTP::LogHandler.new,
#   HTTP::CompressHandler.new,
#   HTTP::StaticFileHandler.new("."),
# ])
#
# server.bind_tcp "127.0.0.1", 8080
# server.listen
# ```
#
# ### Response object
#
# The `HTTP::Server::Response` object has `status` and `headers` properties that can be
# configured before writing the response body. Once any response output has been
# written, changing the `status` and `headers` properties has no effect.
#
# The `HTTP::Server::Response` is a write-only `IO`, so all `IO` methods are available
# on it for sending the response body.
#
# ## Binding to sockets
#
# The server can be bound to one or more server sockets (see `#bind`)
#
# Supported types:
#
# * TCP socket: `#bind_tcp`, `#bind_unused_port`
# * TCP socket with TLS/SSL: `#bind_tls`
# * Unix socket `#bind_unix`
#
# `#bind(uri : URI)` and `#bind(uri : String)` parse socket configuration for
# one of these types from an `URI`. This can be useful for injecting plain text
# configuration values.
#
# Each of these methods returns the `Socket::Address` that was added to this
# server.
#
# ```
# require "http/server"
#
# server = HTTP::Server.new do |context|
#   context.response.content_type = "text/plain"
#   context.response.print "Hello world!"
# end
#
# address = server.bind_tcp "0.0.0.0", 8080
# puts "Listening on http://#{address}"
# server.listen
# ```
#
# It is also possible to bind a generic `Socket::Server` using
# `#bind(socket : Socket::Server)` which can be used for custom network protocol
# configurations.
#
# ## Server loop
#
# After defining all server sockets to listen to, the server can be started by
# calling `#listen`. This call blocks until the server is closed.
#
# A server can be closed by calling `#close`. This closes the server sockets and
# stops processing any new requests, even on connections with keep-alive enabled.
# Currently processing requests are not interrupted but also not waited for.
# In order to give them some grace period for finishing, the calling context
# can add a timeout like `sleep 10.seconds` after `#listen` returns.
#
# ### Reusing connections
#
# The request processor supports reusing a connection for subsequent
# requests. This is used by default for HTTP/1.1 or when requested by
# the `Connection: keep-alive` header. This is signalled by this header being
# set on the `HTTP::Server::Response` when it's passed into the handler chain.
#
# If in the handler chain this header is overridden to `Connection: close`, then
# the connection will not be reused after the request has been processed.
#
# Reusing the connection also requires that the request body (if present) is
# entirely consumed in the handler chain. Otherwise the connection will be closed.
class HTTP::Server < NetworkServer
  Log = ::Log.for("http.server")

  # Creates a new HTTP server with the given block as handler.
  def self.new(&handler : HTTP::Handler::HandlerProc) : self
    new(handler)
  end

  # Creates a new HTTP server with a handler chain constructed from the *handlers*
  # array and the given block.
  def self.new(handlers : Array(HTTP::Handler), &handler : HTTP::Handler::HandlerProc) : self
    new(HTTP::Server.build_middleware(handlers, handler))
  end

  # Creates a new HTTP server with the *handlers* array as handler chain.
  def self.new(handlers : Array(HTTP::Handler)) : self
    new(HTTP::Server.build_middleware(handlers))
  end

  # Creates a new HTTP server with the given *handler*.
  def initialize(handler : HTTP::Handler | HTTP::Handler::HandlerProc)
    @processor = RequestProcessor.new(handler)
  end

  # Returns the maximum permitted size for the request line in an HTTP request.
  #
  # The request line is the first line of a request, consisting of method,
  # resource and HTTP version and the delimiting line break.
  # If the request line has a larger byte size than the permitted size,
  # the server responds with the status code `414 URI Too Long` (see `HTTP::Status::URI_TOO_LONG`).
  #
  # Default: `HTTP::MAX_REQUEST_LINE_SIZE`
  def max_request_line_size : Int32
    @processor.max_request_line_size
  end

  # Sets the maximum permitted size for the request line in an HTTP request.
  def max_request_line_size=(size : Int32)
    @processor.max_request_line_size = size
  end

  # Returns the maximum permitted combined size for the headers in an HTTP request.
  #
  # When parsing a request, the server keeps track of the amount of total bytes
  # consumed for all headers (including line breaks).
  # If combined byte size of all headers is larger than the permitted size,
  # the server responds with the status code `432 Request Header Fields Too Large`
  # (see `HTTP::Status::REQUEST_HEADER_FIELDS_TOO_LARGE`).
  #
  # Default: `HTTP::MAX_HEADERS_SIZE`
  def max_headers_size : Int32
    @processor.max_headers_size
  end

  # Sets the maximum permitted combined size for the headers in an HTTP request.
  def max_headers_size=(size : Int32)
    @processor.max_headers_size = size
  end

  private def handle_client(io : IO)
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
