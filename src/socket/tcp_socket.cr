class TCPSocket < FileDescriptorIO
  def initialize(host, port)
    server = C.gethostbyname(host)
    unless server
      raise Errno.new("Error resolving hostname '#{host}'")
    end

    sock = C.socket(C::AF_INET, C::SOCK_STREAM, 0)

    addr = C::SockAddrIn.new
    addr.family = C::AF_INET
    addr.addr = (server.value.addrlist[0] as UInt32*).value
    addr.port = C.htons(port)

    if C.connect(sock, pointerof(addr), 16) != 0
      raise Errno.new("Error connecting to '#{host}:#{port}'")
    end

    super sock
  end

  def self.open(host, port)
    sock = new(host, port)
    begin
      yield sock
    ensure
      sock.close
    end
  end
end
