class TCPServer
  def initialize(port, backlog = 128)
    @sock = C.socket(C::AF_INET, C::SOCK_STREAM, 0)

    addr = C::SockAddrIn.new
    addr.family = C::AF_INET
    addr.addr = 0_u32
    addr.port = C.htons(port)
    if C.bind(@sock, pointerof(addr), 16) != 0
      raise Errno.new("Error binding TCP server at #{port}")
    end

    if C.listen(@sock, backlog) != 0
      raise Errno.new("Error listening TCP server at #{port}")
    end
  end

  def accept
    client_addr = C::SockAddrIn.new
    client_addr_len = 16
    client_fd = C.accept(@sock, pointerof(client_addr), pointerof(client_addr_len))
    FileDescriptorIO.new(client_fd)
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
