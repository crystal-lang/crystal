require "./tcp_socket"

# A Transmission Control Protocol (TCP/IP) server.
#
# NOTE: To use `TCPServer`, you must explicitly import it with `require "socket"`
#
# Usage example:
# ```
# require "socket"
#
# def handle_client(client)
#   message = client.gets
#   client.puts message
# end
#
# server = TCPServer.new("localhost", 1234)
# while client = server.accept?
#   spawn handle_client(client)
# end
# ```
#
# Options:
# - *host* local interface to bind on, or `::` to bind on all local interfaces.
# - *port* specific port to bind on, or `0` to receive an "ephemeral" (free, assigned by kernel) port.
# - *backlog* to specify how many pending connections are allowed.
# - *reuse_port* to enable multiple processes to bind to the same port (`SO_REUSEPORT`).
class TCPServer < TCPSocket
  include Socket::Server

  # Creates a new `TCPServer`, waiting to be bound.
  def self.new(family : Family = Family::INET)
    super(family)
  end

  # Binds a socket to the *host* and *port* combination.
  def initialize(host : String, port : Int, backlog : Int = SOMAXCONN, dns_timeout = nil, reuse_port : Bool = false)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)

      self.reuse_address = true
      self.reuse_port = true if reuse_port

      if errno = system_bind(addrinfo, "#{host}:#{port}") { |errno| errno }
        close
        next errno
      end

      if errno = listen(backlog) { |errno| errno }
        close
        next errno
      end
    end
  end

  # Creates a TCPServer from an already configured raw file descriptor
  def initialize(*, fd : Handle, family : Family = Family::INET)
    super(fd: fd, family: family)
  end

  # Creates a new TCP server, listening on all local interfaces (`::`).
  def self.new(port : Int, backlog = SOMAXCONN, reuse_port = false)
    new("::", port, backlog, reuse_port: reuse_port)
  end

  # Creates a new TCP server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port, backlog = SOMAXCONN, reuse_port = false, &)
    server = new(host, port, backlog, reuse_port: reuse_port)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Creates a new TCP server, listening on all interfaces, and yields it to the
  # block. Eventually closes the server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(port : Int, backlog = SOMAXCONN, reuse_port = false, &)
    server = new(port, backlog, reuse_port: reuse_port)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Accepts an incoming connection.
  #
  # Returns the client `TCPSocket` or `nil` if the server is closed after invoking
  # this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2022)
  # loop do
  #   if socket = server.accept?
  #     # handle the client in a fiber
  #     spawn handle_connection(socket)
  #   else
  #     # another fiber closed the server
  #     break
  #   end
  # end
  # ```
  def accept? : TCPSocket?
    if client_fd = system_accept
      sock = TCPSocket.new(fd: client_fd, family: family, type: type, protocol: protocol)
      sock.sync = sync?
      sock
    end
  end
end
