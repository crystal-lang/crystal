require "./tcp_socket"

# A Transmission Control Protocol (TCP/IP) server.
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
# - *backlog* to specify how many pending connections are allowed;
# - *reuse_port* to enable multiple processes to bind to the same port (`SO_REUSEPORT`).
class TCPServer < TCPSocket
  include Socket::Server

  # Creates a new `TCPServer`, waiting to be bound.
  def self.new(family : Family = Family::INET)
    super(family)
  end

  # Binds a socket to the *host* and *port* combination.
  def initialize(host : String, port : Int, backlog = SOMAXCONN, dns_timeout = nil, reuse_port = false)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)

      self.reuse_address = true
      self.reuse_port = true if reuse_port

      if errno = bind(addrinfo) { |errno| errno }
        close
        next errno
      end

      if errno = listen(backlog) { |errno| errno }
        close
        next errno
      end
    end
  end

  # Creates a new TCP server, listening on all local interfaces (`::`).
  def self.new(port : Int, backlog = SOMAXCONN, reuse_port = false)
    new("::", port, backlog, reuse_port: reuse_port)
  end

  # Creates a new TCP server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port, backlog = SOMAXCONN, reuse_port = false)
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
  def self.open(port : Int, backlog = SOMAXCONN, reuse_port = false)
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
  def accept?
    if client_fd = accept_impl
      sock = TCPSocket.new(client_fd, family, type, protocol)
      sock.sync = sync?
      sock
    end
  end
end
