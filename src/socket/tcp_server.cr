require "./tcp_socket"

class TCPServer < TCPSocket
  def initialize(host, port, backlog = 128)
    getaddrinfo(host, port, nil, C::SOCK_STREAM, C::IPPROTO_TCP) do |ai|
      sock = C.socket(afamily(ai.family), ai.socktype, ai.protocol)
      raise Errno.new("Error opening socket") if sock <= 0

      optval = 1
      C.setsockopt(sock, C::SOL_SOCKET, C::SO_REUSEADDR, pointerof(optval) as Void*, sizeof(Int32))

      if C.bind(sock, ai.addr as C::SockAddr*, ai.addrlen) != 0
        next false if ai.next
        raise Errno.new("Error binding TCP server at #{host}#{port}")
      end

      if C.listen(sock, backlog) != 0
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
    client_addr :: C::SockAddrIn6
    client_addr_len = sizeof(C::SockAddrIn6)
    client_fd = C.accept(fd, pointerof(client_addr) as C::SockAddr*, pointerof(client_addr_len))
    TCPSocket.new(client_fd)
  end

  def accept
    sock = accept
    begin
      yield sock
    ensure
      sock.close
    end
  end
end
