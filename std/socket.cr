lib C
  struct SockAddrIn
    len : Char
    family : Char
    port : Short
    addr : Int
    zero : Long
  end
  fun socket(domain : Int, t : Int, protocol : Int) : Int
  fun htons(n : Int) : Short
  fun bind(fd : Int, addr : SockAddrIn*, addr_len : Int) : Int
  fun listen(fd : Int, backlog : Int) : Int
  fun accept(fd : Int, addr : SockAddrIn*, addr_len : Int*) : Int
  fun fdopen(fd : Int, mode : Char*) : File
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
      puts "Error binding socket"
      exit(1)
    end

    if C.listen(@sock, 5) != 0
      puts "Error listening socket"
      exit(1)
    end
  end

  def accept
    client_addr = C::SockAddrIn.new
    client_addr_len = 16
    client_fd = C.accept(@sock, client_addr.ptr, client_addr_len.ptr)
    Socket.new(client_fd)
  end
end

