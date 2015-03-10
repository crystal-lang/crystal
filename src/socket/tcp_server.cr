require "./tcp_socket"

class TCPServer < TCPSocket
  def initialize(host, port, backlog = 128)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP) do |ai|
      sock = LibC.socket(afamily(ai.family), ai.socktype, ai.protocol)
      raise Errno.new("Error opening socket") if sock <= 0

      optval = 1
      LibC.setsockopt(sock, LibC::SOL_SOCKET, LibC::SO_REUSEADDR, pointerof(optval) as Void*, sizeof(Int32))

      if LibC.bind(sock, ai.addr as LibC::SockAddr*, ai.addrlen) != 0
        LibC.close(sock)
        next false if ai.next
        raise Errno.new("Error binding TCP server at #{host}#{port}")
      end

      if LibC.listen(sock, backlog) != 0
        LibC.close(sock)
        next false if ai.next
        raise Errno.new("Error listening TCP server at #{host}#{port}")
      end

      super sock

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

  def accept
    sock = accept
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def accept
    loop do
      client_addr :: LibC::SockAddrIn6
      client_addr_len = sizeof(LibC::SockAddrIn6)
      client_fd = LibC.accept(fd, pointerof(client_addr) as LibC::SockAddr*, pointerof(client_addr_len))
      if client_fd == -1
        if LibC.errno == Errno::EAGAIN
          readers << Fiber.current
          Scheduler.reschedule
        else
          raise Errno.new "Error accepting socket"
        end
      else
        return TCPSocket.new(client_fd)
      end
    end
  end
end
