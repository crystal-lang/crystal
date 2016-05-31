require "./tcp_socket"

class TCPServer < TCPSocket
  def initialize(host, port, backlog = 128)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP) do |addrinfo|
      sock = create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol)
      super sock

      self.reuse_address = true

      if LibC.bind(sock, addrinfo.ai_addr.as(LibC::Sockaddr*), addrinfo.ai_addrlen) != 0
        errno = Errno.new("Error binding TCP server at #{host}:#{port}")
        LibC.close(sock)
        next false if addrinfo.ai_next
        raise errno
      end

      if LibC.listen(sock, backlog) != 0
        errno = Errno.new("Error listening TCP server at #{host}:#{port}")
        LibC.close(sock)
        next false if addrinfo.ai_next
        raise errno
      end

      true
    end
  end

  def self.new(port : Int, backlog = 128)
    new("::", port, backlog)
  end

  def self.open(host, port, backlog = 128)
    server = new(host, port, backlog)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Accepts an incoming connection, yields it to the given
  # block, and then closes the conneciton. Returns the
  # value of the block.
  #
  # If the server is closed after invoking this method,
  # `IO::Error` (closed stream) is raised.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  #
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

  # Accepts an incoming connection, yields it to the given
  # block, and then closes the conneciton. Returns the
  # value of the block, or `nil` if the server is closed
  # after invoking this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  #
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
  # If the server is closed after invoking this method,
  # `IO::Error` (closed stream) is raised.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  #
  # socket = server.accept
  # socket.puts Time.now
  # socket.close
  # ```
  def accept : TCPSocket
    accept? || raise IO::Error.new("closed stream")
  end

  # Accepts an incoming connection.
  #
  # If the server is closed after invoking this method,
  # `nil` is returned.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  #
  # socket = server.accept?
  # if socket
  #   socket.puts Time.now
  #   socket.close
  # else
  #   # This might happen if another fiber closes the server
  #   # (can't happen in this example)
  #   puts "server was closed"
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
