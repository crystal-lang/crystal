lib C
  struct SockAddrIn
    len : Char
    family : UInt8
    port : Int16
    addr : UInt32
    zero : Int64
  end

  struct HostEnt
    name : Char*
    aliases : Char**
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
  fun gethostbyname(name : Char*) : HostEnt*
  fun close(fd : Int32) : Int32

  AF_INET = 2_u8
  SOCK_STREAM = 1
end

class Socket
  include IO

  def initialize(fd)
    @input = C.fdopen(fd, "r")
    @output = C.fdopen(fd, "w")
  end

  def input
    @input
  end

  def output
    @output
  end

  def close
    C.fclose @input
    C.fclose @output
  end
end

class TCPSocket < Socket
  def initialize(host, port)
    server = C.gethostbyname(host)
    unless server
      raise Errno.new
    end

    server = server.value
    @sock = C.socket(C::AF_INET, C::SOCK_STREAM, 0)

    addr = C::SockAddrIn.new
    addr.family = C::AF_INET
    addr.addr = server.addrlist[0].as(UInt32).value
    addr.port = C.htons(port)

    if C.connect(@sock, addr.ptr, 16) != 0
      raise Errno.new
    end

    super @sock
  end

  def close
    if C.close(@sock) != 0
      raise Errno.new
    end
  end
end

class TCPServer
  def initialize(port)
    @sock = C.socket(C::AF_INET, C::SOCK_STREAM, 0)

    addr = C::SockAddrIn.new
    addr.family = C::AF_INET
    addr.addr = 0_u32
    addr.port = C.htons(port)
    if C.bind(@sock, addr.ptr, 16) != 0
      raise Errno.new
    end

    if C.listen(@sock, 5) != 0
      raise Errno.new
    end
  end

  def accept
    client_addr = C::SockAddrIn.new
    client_addr_len = 16
    client_fd = C.accept(@sock, client_addr.ptr, client_addr_len.ptr)
    Socket.new(client_fd)
  end
end

