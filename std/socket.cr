lib C
  struct SockAddrIn
    len : Char
    family : Char
    port : Int16
    addr : Int32
    zero : Int64
  end
  fun socket(domain : Int32, t : Int32, protocol : Int32) : Int32
  fun htons(n : Int32) : Int16
  fun bind(fd : Int32, addr : SockAddrIn*, addr_len : Int32) : Int32
  fun listen(fd : Int32, backlog : Int32) : Int32
  fun accept(fd : Int32, addr : SockAddrIn*, addr_len : Int32*) : Int32
  fun fdopen(fd : Int32, mode : Char*) : File
end

class Socket < IO
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
end

class TCPServer
  AF_INET = 2
  SOCK_STREAM = 1

  def initialize(port)
    @sock = C.socket(AF_INET, SOCK_STREAM, 0);

    addr = C::SockAddrIn.new
    addr.family = AF_INET.chr
    addr.addr = 0
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

