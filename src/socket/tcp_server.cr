require "./tcp_socket"

# A Transmission Control Protocol (TCP/IP) server.
#
# Usage example:
# ```
# server = TCPServer.new("localhost", 1234)
# loop do
#   server.accept do |client|
#     message = client.gets
#     client << message # echo the message back
#   end
# end
# ```
class TCPServer < TCPSocket
  def initialize(host, port, backlog = 128)
    getaddrinfo(host, port, nil, Type::STREAM, Protocol::TCP) do |addrinfo|
      super create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol)

      self.reuse_address = true

      if LibC.bind(@fd, addrinfo.ai_addr.as(LibC::Sockaddr*), addrinfo.ai_addrlen) != 0
        errno = Errno.new("Error binding TCP server at #{host}:#{port}")
        close
        next false if addrinfo.ai_next
        raise errno
      end

      if LibC.listen(@fd, backlog) != 0
        errno = Errno.new("Error listening TCP server at #{host}:#{port}")
        close
        next false if addrinfo.ai_next
        raise errno
      end

      true
    end
  end

  # Creates a new TCP server, listening on all local interfaces (`::`).
  def self.new(port : Int, backlog = 128)
    new("::", port, backlog)
  end

  # Creates a new TCP server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port, backlog = 128)
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
  def self.open(port : Int, backlog = 128)
    server = new(port, backlog)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Accepts an incoming connection and yields the client socket to the block.
  # Eventually closes the connection when the block returns.
  #
  # Returns the value of the block. If the server is closed after invoking this
  # method, an `IO::Error` (closed stream) exception will be raised.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  # server.accept do |socket|
  #   socket.puts Time.now
  # end
  # ```
  def accept
    sock = accept
    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Accepts an incoming connection and yields the client socket to the block.
  # Eventualy closes the connection when the block returns.
  #
  # Returns the value of the block or `nil` if the server is closed after
  # invoking this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  # server.accept? do |socket|
  #   socket.puts Time.now
  # end
  # ```
  def accept?
    sock = accept?
    return unless sock

    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Accepts an incoming connection.
  #
  # Returns the client socket. Raises an `IO::Error` (closed stream) exception
  # if the server is closed after invoking this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  # socket = server.accept
  # socket.puts Time.now
  # socket.close
  # ```
  def accept : TCPSocket
    accept? || raise IO::Error.new("closed stream")
  end

  # Accepts an incoming connection.
  #
  # Returns the client socket or `nil` if the server is closed after invoking
  # this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
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
    loop do
      client_addr = uninitialized LibC::SockaddrIn6
      client_addr_len = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))
      client_fd = LibC.accept(fd, pointerof(client_addr).as(LibC::Sockaddr*), pointerof(client_addr_len))
      if client_fd == -1
        return nil if closed?

        if Errno.value == Errno::EAGAIN
          wait_readable
        else
          raise Errno.new "Error accepting socket"
        end
      else
        sock = TCPSocket.new(client_fd)
        sock.sync = sync?
        return sock
      end
    end
  end
end
