require "socket"
require "uri"
require "./server/context"
require "./server/handler"
require "./server/response"
require "./common"
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
# The server can be bound to one ore more server sockets (see `#bind`)
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
class HTTP::Server
  @sockets = [] of Socket::Server

  # Returns `true` if this server is closed.
  getter? closed : Bool = false

  # Returns `true` if this server is listening on its sockets.
  getter? listening : Bool = false

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

  # Creates a `TCPServer` listening on `host:port` and adds it as a socket, returning the local address
  # and port the server listens on.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind_tcp("127.0.0.100", 8080) # => Socket::IPAddress.new("127.0.0.100", 8080)
  # ```
  #
  # If *reuse_port* is `true`, it enables the `SO_REUSEPORT` socket option,
  # which allows multiple processes to bind to the same port.
  def bind_tcp(host : String, port : Int32, reuse_port : Bool = false) : Socket::IPAddress
    tcp_server = TCPServer.new(host, port, reuse_port: reuse_port)

    bind(tcp_server)

    tcp_server.local_address
  end

  # Creates a `TCPServer` listening on `127.0.0.1:port` and adds it as a socket,
  # returning the local address and port the server listens on.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind_tcp(8080) # => Socket::IPAddress.new("127.0.0.1", 8080)
  # ```
  #
  # If *reuse_port* is `true`, it enables the `SO_REUSEPORT` socket option,
  # which allows multiple processes to bind to the same port.
  def bind_tcp(port : Int32, reuse_port : Bool = false) : Socket::IPAddress
    bind_tcp Socket::IPAddress::LOOPBACK, port, reuse_port
  end

  # Creates a `TCPServer` listening on *address* and adds it as a socket, returning the local address
  # and port the server listens on.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind_tcp(Socket::IPAddress.new("127.0.0.100", 8080)) # => Socket::IPAddress.new("127.0.0.100", 8080)
  # server.bind_tcp(Socket::IPAddress.new("127.0.0.100", 0))    # => Socket::IPAddress.new("127.0.0.100", 35487)
  # ```
  #
  # If *reuse_port* is `true`, it enables the `SO_REUSEPORT` socket option,
  # which allows multiple processes to bind to the same port.
  def bind_tcp(address : Socket::IPAddress, reuse_port : Bool = false) : Socket::IPAddress
    bind_tcp(address.address, address.port, reuse_port: reuse_port)
  end

  # Creates a `TCPServer` listening on an unused port and adds it as a socket.
  #
  # Returns the `Socket::IPAddress` with the determined port number.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind_unused_port # => Socket::IPAddress.new("127.0.0.1", 12345)
  # ```
  def bind_unused_port(host : String = Socket::IPAddress::LOOPBACK, reuse_port : Bool = false) : Socket::IPAddress
    bind_tcp host, 0, reuse_port
  end

  # Creates a `UNIXServer` bound to *path* and adds it as a socket.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind_unix "/tmp/my-socket.sock"
  # ```
  def bind_unix(path : String) : Socket::UNIXAddress
    server = UNIXServer.new(path)

    bind(server)

    server.local_address
  end

  # Creates a `UNIXServer` bound to *address* and adds it as a socket.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind_unix(Socket::UNIXAddress.new("/tmp/my-socket.sock"))
  # ```
  def bind_unix(address : Socket::UNIXAddress) : Socket::UNIXAddress
    bind_unix(address.path)
  end

  {% unless flag?(:without_openssl) %}
    # Creates an `OpenSSL::SSL::Server` and adds it as a socket.
    #
    # The SSL server wraps a `TCPServer` listening on `host:port`.
    #
    # ```
    # require "http/server"
    #
    # server = HTTP::Server.new { }
    # context = OpenSSL::SSL::Context::Server.new
    # context.certificate_chain = "openssl.crt"
    # context.private_key = "openssl.key"
    # server.bind_tls "127.0.0.1", 8080, context
    # ```
    def bind_tls(host : String, port : Int32, context : OpenSSL::SSL::Context::Server, reuse_port : Bool = false) : Socket::IPAddress
      tcp_server = TCPServer.new(host, port, reuse_port: reuse_port)
      server = OpenSSL::SSL::Server.new(tcp_server, context)

      bind(server)

      tcp_server.local_address
    end

    # Creates an `OpenSSL::SSL::Server` and adds it as a socket.
    #
    # The SSL server wraps a `TCPServer` listening on an unused port on *host*.
    #
    # ```
    # require "http/server"
    #
    # server = HTTP::Server.new { }
    # context = OpenSSL::SSL::Context::Server.new
    # context.certificate_chain = "openssl.crt"
    # context.private_key = "openssl.key"
    # address = server.bind_tls "127.0.0.1", context
    # ```
    def bind_tls(host : String, context : OpenSSL::SSL::Context::Server) : Socket::IPAddress
      bind_tls(host, 0, context)
    end

    # Creates an `OpenSSL::SSL::Server` and adds it as a socket.
    #
    # The SSL server wraps a `TCPServer` listening on an unused port on *host*.
    #
    # ```
    # require "http/server"
    #
    # server = HTTP::Server.new { }
    # context = OpenSSL::SSL::Context::Server.new
    # context.certificate_chain = "openssl.crt"
    # context.private_key = "openssl.key"
    # address = server.bind_tls Socket::IPAddress.new("127.0.0.1", 8000), context
    # ```
    def bind_tls(address : Socket::IPAddress, context : OpenSSL::SSL::Context::Server) : Socket::IPAddress
      bind_tls(address.address, address.port, context)
    end
  {% end %}

  # Parses a socket configuration from *uri* and adds it to this server.
  # Returns the effective address it is bound to.
  #
  # ```
  # require "http/server"
  #
  # server = HTTP::Server.new { }
  # server.bind("tcp://localhost:80")                                                  # => Socket::IPAddress.new("127.0.0.1", 8080)
  # server.bind("unix:///tmp/server.sock")                                             # => Socket::UNIXAddress.new("/tmp/server.sock")
  # server.bind("tls://127.0.0.1:443?key=private.key&cert=certificate.cert&ca=ca.crt") # => Socket::IPAddress.new("127.0.0.1", 443)
  # ```
  def bind(uri : String) : Socket::Address
    bind(URI.parse(uri))
  end

  # :ditto:
  def bind(uri : URI) : Socket::Address
    case uri.scheme
    when "tcp"
      bind_tcp(Socket::IPAddress.parse(uri))
    when "unix"
      bind_unix(Socket::UNIXAddress.parse(uri))
    when "tls", "ssl"
      address = Socket::IPAddress.parse(uri)
      {% unless flag?(:without_openssl) %}
        context = OpenSSL::SSL::Context::Server.from_hash(HTTP::Params.parse(uri.query || ""))

        bind_tls(address, context)
      {% else %}
        raise ArgumentError.new "Unsupported socket type: #{uri.scheme} (program was compiled without openssl support)"
      {% end %}
    else
      raise ArgumentError.new "Unsupported socket type: #{uri.scheme}"
    end
  end

  # Adds a `Socket::Server` *socket* to this server.
  def bind(socket : Socket::Server) : Nil
    raise "Can't add socket to running server" if listening?
    raise "Can't add socket to closed server" if closed?

    @sockets << socket
  end

  # Enumerates all addresses this server is bound to.
  def each_address(&block : Socket::Address ->)
    @sockets.each do |socket|
      yield socket.local_address
    end
  end

  def addresses : Array(Socket::Address)
    array = [] of Socket::Address
    each_address do |address|
      array << address
    end
    array
  end

  # Creates a `TCPServer` listening on `127.0.0.1:port`, adds it as a socket
  # and starts the server. Blocks until the server is closed.
  #
  # See `#bind(port : Int32)` for details.
  def listen(port : Int32, reuse_port : Bool = false)
    bind_tcp(port, reuse_port)

    listen
  end

  # Creates a `TCPServer` listening on `host:port`, adds it as a socket
  # and starts the server. Blocks until the server is closed.
  #
  # See `#bind(host : String, port : Int32)` for details.
  def listen(host : String, port : Int32, reuse_port : Bool = false)
    bind_tcp(host, port, reuse_port)

    listen
  end

  # Starts the server. Blocks until the server is closed.
  def listen
    raise "Can't re-start closed server" if closed?
    raise "Can't start server with no sockets to listen to, use HTTP::Server#bind first" if @sockets.empty?
    raise "Can't start running server" if listening?

    @listening = true
    done = Channel(Nil).new

    @sockets.each do |socket|
      spawn do
        until closed?
          io = begin
            socket.accept?
          rescue e
            handle_exception(e)
            nil
          end

          if io
            # a non nillable version of the closured io
            _io = io
            spawn handle_client(_io)
          end
        end
      ensure
        done.send nil
      end
    end

    @sockets.size.times { done.receive }
  end

  # Gracefully terminates the server. It will process currently accepted
  # requests, but it won't accept new connections.
  def close
    raise "Can't close server, it's already closed" if closed?

    @closed = true
    @processor.close

    @sockets.each do |socket|
      socket.close
    rescue
      # ignore exception on close
    end

    @listening = false
    @sockets.clear
  end

  private def handle_client(io : IO)
    if io.is_a?(IO::Buffered)
      io.sync = false
    end

    @processor.process(io, io)
  end

  private def handle_exception(e : Exception)
    e.inspect_with_backtrace STDERR
    STDERR.flush
  end

  # Builds all handlers as the middleware for `HTTP::Server`.
  def self.build_middleware(handlers, last_handler : (Context ->)? = nil)
    raise ArgumentError.new "You must specify at least one HTTP Handler." if handlers.empty?
    0.upto(handlers.size - 2) { |i| handlers[i].next = handlers[i + 1] }
    handlers.last.next = last_handler if last_handler
    handlers.first
  end
end
