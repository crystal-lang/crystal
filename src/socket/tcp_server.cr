require "./tcp_socket"
require "./server"

# A Transmission Control Protocol (TCP/IP) server.
#
# Usage example:
# ```
# require "socket/tcp_server"
#
# def handle_client(client)
#   message = client.gets
#   client.puts message
# end
#
# TCPServer.open("localhost", 1234) do |server|
#   while client = server.accept?
#     spawn handle_client(client)
#   end
# end
# ```
#
# Options:
# - *backlog* to specify how many pending connections are allowed.
# - *reuse_port* to enable multiple processes to bind to the same port (`SO_REUSEPORT`).
# - *reuse_address* to enable multiple processes to bind to the same address (`SO_REUSEADDR`).
# - *dns_timeout* to specify the timeout for DNS lookups when binding to a hostname.
struct TCPServer
  include Socket::Server

  # Returns the raw socket wrapped by this TCP server.
  getter raw : Socket::Raw

  # Creates a `TCPServer` from a raw socket.
  def initialize(@raw : Socket::Raw)
  end

  # Creates a `TCPServer` listening on *port* on all interfaces specified by *host*.
  #
  # *host* can either be an IP address or a hostname.
  def self.new(host : String, port : Int, *,
               backlog : Int32 = Socket::SOMAXCONN, dns_timeout : Time::Span? = nil,
               reuse_port : Bool = false, reuse_address : Bool = true) : TCPServer
    Socket::Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      raw = Socket::Raw.new(addrinfo.family, addrinfo.type, addrinfo.protocol)

      raw.reuse_address = reuse_address
      raw.reuse_port = true if reuse_port

      if errno = raw.bind(addrinfo) { |errno| errno }
        raw.close
        next errno
      end

      if errno = raw.listen(backlog: backlog) { |errno| errno }
        raw.close
        next errno
      end

      return new(raw)
    end
  end

  # Creates a new `TCPServer` listening on *address*.
  def self.new(address : Socket::IPAddress, *,
               backlog : Int32 = Socket::SOMAXCONN,
               reuse_port : Bool = false, reuse_address : Bool = true) : TCPServer
    raw = Socket::Raw.new(address.family, Socket::Type::STREAM, Socket::Protocol::TCP)

    raw.reuse_address = reuse_address
    raw.reuse_port = true if reuse_port

    raw.bind(address)
    raw.listen(backlog: backlog)

    new(raw)
  end

  # Creates a new `TCPServer`, listening on *port* on all local interfaces (`::`).
  def self.new(port : Int, *,
               backlog : Int32 = Socket::SOMAXCONN,
               reuse_port : Bool = false, reuse_address : Bool = true) : TCPServer
    new(Socket::IPAddress.new("::", port), backlog: backlog, reuse_port: reuse_port, reuse_address: reuse_address)
  end

  # Creates a new `TCPServer` listening on *address*, and yields it to the block.
  # Eventually closes the server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(address : Socket::IPAddress, *,
                backlog : Int32 = Socket::SOMAXCONN,
                reuse_port : Bool = false, reuse_address : Bool = true)
    server = new(address, backlog: backlog, reuse_port: reuse_port, reuse_address: reuse_address)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Creates a new `TCPServer` listenting on *host* and *port*, and yields it to the block.
  # Eventually closes the server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host : String, port : Int, *,
                backlog : Int32 = Socket::SOMAXCONN, dns_timeout : Time::Span? = nil,
                reuse_port : Bool = false, reuse_address : Bool = true)
    server = new(host, port, backlog: backlog, dns_timeout: dns_timeout, reuse_port: reuse_port, reuse_address: reuse_address)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Creates a new `TCPServer`, listening on all interfaces on *port*, and yields it to the
  # block.
  # Eventually closes the server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(port : Int, *,
                backlog : Int32 = Socket::SOMAXCONN,
                reuse_port : Bool = false, reuse_address : Bool = true)
    server = new(port, backlog: backlog, reuse_port: reuse_port, reuse_address: reuse_address)
    begin
      yield server
    ensure
      server.close
    end
  end

  Socket.delegate_close
  Socket.delegate_sync
  Socket.delegate_tcp_options

  # Returns the receive buffer size for this socket.
  def recv_buffer_size : Int32
    @raw.recv_buffer_size
  end

  # Sets the receive buffer size for this socket.
  def recv_buffer_size=(value : Int32) : Nil
    @raw.recv_buffer_size = value
  end

  # Returns `true` if this socket has been configured to reuse the port (see `SO_REUSEPORT`).
  def reuse_port? : Bool
    @raw.reuse_port?
  end

  # Returns `true` if this socket has been configured to reuse the address (see `SO_REUSEADDR`).
  def reuse_address? : Bool
    @raw.reuse_address?
  end

  # Accepts an incoming connection.
  #
  # Returns the client `TCPSocket` or `nil` if the server is closed after invoking
  # this method.
  #
  # ```
  # require "socket/tcp_server"
  #
  # TCPServer.open(2022) do |server|
  #   loop do
  #     if socket = server.accept?
  #       # handle the client in a fiber
  #       spawn handle_connection(socket)
  #     else
  #       # another fiber closed the server
  #       break
  #     end
  #   end
  # end
  # ```
  def accept? : TCPSocket?
    if socket = @raw.accept?
      TCPSocket.new(socket)
    end
  end

  # Accepts an incoming connection and returns the client `TCPSocket`.
  #
  # ```
  # require "socket/tcp_server"
  #
  # TCPServer.open(2022) do |server|
  #   loop do
  #     socket = server.accept
  #     # handle the client in a fiber
  #     spawn handle_connection(socket)
  #   end
  # end
  # ```
  #
  # Raises if the server is closed after invoking this method.
  def accept : TCPSocket
    TCPSocket.new @raw.accept
  end

  # Returns the `Socket::IPAddress` this server listens on, or `nil` if
  # the socket is closed.
  def local_address? : Socket::IPAddress?
    local_address unless closed?
  end

  # Returns the `Socket::IPAddress` this server listens on.
  #
  # Raises `Socket::Error` if the socket is closed.
  def local_address : Socket::IPAddress
    @raw.local_address(Socket::IPAddress)
  end
end
