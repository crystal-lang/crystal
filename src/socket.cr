lib C
  ifdef darwin
    struct SockAddrIn
      len : UInt8
      family : UInt8
      port : Int16
      addr : UInt32
      zero : Int64
    end
  else
    struct SockAddrIn
      family : UInt8
      port : Int16
      addr : UInt32
      zero : Int64
    end
  end

  struct HostEnt
    name : UInt8*
    aliases : UInt8**
    addrtype : Int32
    length : Int32
    addrlist : UInt8**
  end


  fun socket(domain : UInt8, t : Int32, protocol : Int32) : Int32
  fun htons(n : Int32) : Int16
  fun bind(fd : Int32, addr : SockAddrIn*, addr_len : Int32) : Int32
  fun listen(fd : Int32, backlog : Int32) : Int32
  fun accept(fd : Int32, addr : SockAddrIn*, addr_len : Int32*) : Int32
  fun connect(fd : Int32, addr : SockAddrIn*, addr_len : Int32) : Int32
  fun gethostbyname(name : UInt8*) : HostEnt*

  AF_INET = 2_u8
  SOCK_STREAM = 1
end

class TCPSocket < FileDescriptorIO
  def initialize(host, port)
    server = C.gethostbyname(host)
    unless server
      raise Errno.new("Error resolving hostname '#{host}'")
    end

    sock = C.socket(C::AF_INET, C::SOCK_STREAM, 0)

    addr :: C::SockAddrIn
    addr.family = C::AF_INET
    addr.addr = (server->addrlist[0] as UInt32*).value
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

class TCPServer
  def initialize(port)
    @sock = C.socket(C::AF_INET, C::SOCK_STREAM, 0)

    addr :: C::SockAddrIn
    addr.family = C::AF_INET
    addr.addr = 0_u32
    addr.port = C.htons(port)
    if C.bind(@sock, pointerof(addr), 16) != 0
      raise Errno.new("Error binding TCP server at #{port}")
    end

    if C.listen(@sock, 5) != 0
      raise Errno.new("Error listening TCP server at #{port}")
    end
  end

  def accept
    client_addr :: C::SockAddrIn
    client_addr_len = 16
    client_fd = C.accept(@sock, pointerof(client_addr), pointerof(client_addr_len))
    FileDescriptorIO.new(client_fd)
  end
end
