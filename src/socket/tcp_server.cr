require "./tcp_socket"

# A Transmission Control Protocol (TCP/IP) server.
#
# Usage example:
# ```
# require "socket"
#
# server = TCPServer.new("localhost", 1234)
# loop do
#   server.accept do |client|
#     message = client.gets
#     client << message # echo the message back
#   end
# end
# ```
class TCPServer < TCPSocket
  include Socket::Server

  # Creates a new `TCPServer`, waiting to be bound.
  def self.new(family : Family = Family::INET)
    super(family)
  end

  def initialize(host : String, port : Int, backlog = SOMAXCONN, dns_timeout = nil)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)

      self.reuse_address = true
      self.reuse_port = true

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
  def self.new(port : Int, backlog = SOMAXCONN)
    new("::", port, backlog)
  end

  # Creates a new TCP server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port, backlog = SOMAXCONN)
    server = new(host, port, backlog)
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
  def self.open(port : Int, backlog = SOMAXCONN)
    server = new(port, backlog)
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
