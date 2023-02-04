require "socket"

# This class wraps another `::Socket::Server` in an SSL layer.
#
# ```
# require "socket"
# require "openssl"
#
# tcp_server = TCPServer.new(0)
#
# ssl_context = OpenSSL::SSL::Context::Server.new
# ssl_context.certificate_chain = "openssl.crt"
# ssl_context.private_key = "openssl.key"
# ssl_server = OpenSSL::SSL::Server.new(tcp_server, ssl_context)
#
# puts "SSL Server listening on #{tcp_server.local_address}"
# while connection = ssl_server.accept?
#   connection.puts "secure message"
#   connection.close
# end
# ```
class OpenSSL::SSL::Server
  include ::Socket::Server

  # Returns the wrapped server socket.
  getter wrapped : ::Socket::Server

  # Returns the SSL context.
  getter context : OpenSSL::SSL::Context::Server

  # If `#sync_close?` is `true`, closing this server will
  # close the wrapped server.
  property? sync_close : Bool

  # Returns `true` if this SSL server has been closed.
  getter? closed : Bool = false

  # When `true` a call to `#accept` will also initiate the SSL handshake.
  property start_immediately : Bool = true

  # Creates a new SSL server wrapping *wrapped*.
  #
  # *context* configures the SSL options, see `OpenSSL::SSL::Context::Server` for details
  def initialize(@wrapped : ::Socket::Server, @context : OpenSSL::SSL::Context::Server = OpenSSL::SSL::Context::Server.new, @sync_close : Bool = true)
  end

  # Creates a new SSL server wrapping *wrapped*  and yields it to the block.
  #
  # *context* configures the SSL options, see `OpenSSL::SSL::Context::Server` for details
  #
  # The server is closed after the block returns.
  def self.open(wrapped : ::Socket::Server, context : OpenSSL::SSL::Context::Server = OpenSSL::SSL::Context::Server.new, sync_close : Bool = true, &)
    server = new(wrapped, context, sync_close)

    begin
      yield server
    ensure
      server.close
    end
  end

  # Implements `::Socket::Server#accept`.
  #
  # This method calls `@wrapped.accept` and wraps the resulting IO in a SSL socket (`OpenSSL::SSL::Socket::Server`) with `context` configuration.
  def accept : OpenSSL::SSL::Socket::Server
    new_ssl_socket(@wrapped.accept)
  end

  # Implements `::Socket::Server#accept?`.
  #
  # This method calls `@wrapped.accept?` and wraps the resulting IO in a SSL socket (`OpenSSL::SSL::Socket::Server`) with `context` configuration.
  def accept? : OpenSSL::SSL::Socket::Server?
    if socket = @wrapped.accept?
      new_ssl_socket(socket)
    end
  end

  private def new_ssl_socket(io)
    OpenSSL::SSL::Socket::Server.new(io, @context, sync_close: @sync_close, accept: @start_immediately)
  end

  # Closes this SSL server.
  #
  # Propagates to `wrapped` if `sync_close` is `true`.
  def close : Nil
    return if @closed
    @closed = true

    @wrapped.close if @sync_close
  end

  # Returns local address of `wrapped`.
  def local_address : ::Socket::Address
    @wrapped.local_address
  end
end
