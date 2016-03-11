lib LibC
  alias SocklenT = UInt

  ifdef darwin
    struct Addrinfo
      flags : Int
      family : Int
      socktype : Int
      protocol : Int
      addrlen : SocklenT
      canonname : Char*
      addr : SockAddr*
      next : Addrinfo*
    end
  else
    struct Addrinfo
      flags : Int
      family : Int
      socktype : Int
      protocol : Int
      addrlen : SocklenT
      addr : SockAddr*
      canonname : Char*
      next : Addrinfo*
    end
  end

  fun freeaddrinfo(addr : Addrinfo*) : Void
  fun gai_strerror(code : Int) : Char*
  fun getaddrinfo(name : Char*, service : Char*, hints : Addrinfo*, pai : Addrinfo**) : Int

  AI_PASSIVE     = 0x0001
  AI_CANONNAME   = 0x0002
  AI_NUMERICHOST = 0x0004
  AI_V4MAPPED    = 0x0008
  AI_ALL         = 0x0010
  AI_ADDRCONFIG  = 0x0020

  NI_MAXHOST = 1025
  NI_MAXSERV =   32

  NI_NUMERICHOST =  1
  NI_NUMERICSERV =  2
  NI_NOFQDN      =  4
  NI_NAMEREQD    =  8
  NI_DGRAM       = 16

  ifdef darwin
    struct SockAddrIn
      len : UInt8
      family : UInt8
      port : Int16
      addr : UInt32
      zero : Int64
    end

    struct SockAddrIn6
      len : UInt8
      family : UInt8
      port : Int16
      flowinfo : Int32
      addr : StaticArray(UInt8, 16)
      scope_id : UInt32
    end

    struct SockAddrUn
      len : UInt8
      family : UInt8
      path : UInt8[104]
    end

    struct SockAddr
      len : UInt8
      family : UInt8
      data : StaticArray(UInt8, 14)
    end

    alias AddressFamilyType = UInt8

    AF_UNSPEC =  0
    AF_UNIX   =  1
    AF_INET   =  2
    AF_INET6  = 30

    SOL_SOCKET    = 0xffff
    SO_REUSEADDR  = 0x0004
    SO_KEEPALIVE  = 0x0008
    SO_BROADCAST  = 0x0020
    SO_LINGER     = 0x0080
    SO_SNDBUF     = 0x1001
    SO_RCVBUF     = 0x1002
    TCP_NODELAY   =   0x01
    TCP_KEEPIDLE  =   0x10 # aka TCP_KEEPALIVE
    TCP_KEEPINTVL =  0x101
    TCP_KEEPCNT   =  0x102
  else
    struct SockAddrIn
      family : UInt16
      port : Int16
      addr : UInt32
      zero : Int64
    end

    struct SockAddrIn6
      family : UInt16
      port : Int16
      flowinfo : Int32
      addr : StaticArray(UInt8, 16)
      scope_id : UInt32
    end

    struct SockAddrUn
      family : UInt16
      path : UInt8[108]
    end

    struct SockAddr
      family : UInt16
      data : StaticArray(UInt8, 14)
    end

    alias AddressFamilyType = UInt16

    AF_UNSPEC =  0
    AF_UNIX   =  1
    AF_INET   =  2
    AF_INET6  = 10

    SOL_SOCKET    =  1
    SO_REUSEADDR  =  2
    SO_BROADCAST  =  6
    SO_SNDBUF     =  7
    SO_RCVBUF     =  8
    SO_KEEPALIVE  =  9
    SO_LINGER     = 13
    TCP_NODELAY   =  1
    TCP_KEEPIDLE  =  4 # aka TCP_KEEPALIVE
    TCP_KEEPINTVL =  5
    TCP_KEEPCNT   =  6
  end

  struct HostEnt
    name : Char*
    aliases : Char**
    addrtype : Int32
    length : Int32
    addrlist : Char**
  end

  enum Shutdown
    READ  = 0
    WRITE = 1
    RDWR  = 2
  end

  struct Linger
    on : Int
    secs : Int
  end

  fun socket(domain : Int, t : Int, protocol : Int) : Int
  fun socketpair(domain : Int, t : Int, protocol : Int, sockets : StaticArray(Int, 2)*) : Int
  fun inet_pton(af : Int, src : Char*, dst : Void*) : Int
  fun inet_ntop(af : Int, src : Void*, dst : Char*, size : SocklenT) : Char*
  fun htons(n : UInt16) : UInt16
  fun ntohs(n : UInt16) : UInt16
  fun bind(fd : Int, addr : SockAddr*, addr_len : SocklenT) : Int
  fun listen(fd : Int, backlog : Int) : Int
  fun accept(fd : Int, addr : SockAddr*, addr_len : SocklenT*) : Int
  fun connect(fd : Int, addr : SockAddr*, addr_len : SocklenT) : Int
  fun gethostbyname(name : Char*) : HostEnt*
  fun getsockname(fd : Int, addr : SockAddr*, addr_len : SocklenT*) : Int
  fun getpeername(fd : Int, addr : SockAddr*, addr_len : SocklenT*) : Int
  fun getsockopt(sock : Int, level : Int, opt : Int, optval : Void*, optlen : SocklenT*) : Int
  fun setsockopt(sock : Int, level : Int, opt : Int, optval : Void*, optlen : SocklenT) : Int
  fun shutdown(sock : Int, how : Shutdown) : Int
  fun send(sock : Int, buffer : Void*, length : SizeT, flags : Int) : SSizeT
  fun sendto(sock : Int, buffer : Void*, length : SizeT, flags : Int, dest_addr : SockAddr*, dest_len : SocklenT) : SSizeT
  fun recvfrom(sock : Int, buffer : Void*, length : SizeT, flags : Int, addr : SockAddr*, addr_len : SocklenT*) : SSizeT

  SOCK_STREAM = 1
  SOCK_DGRAM  = 2
  SOCK_RAW    = 3

  ifdef linux
    SOCK_CLOEXEC = 0o2000000
  else
    SOCK_CLOEXEC = 0 # workaround in init_close_on_exec
  end

  IPPROTO_IP  =   0
  IPPROTO_TCP =   6
  IPPROTO_UDP =  17
  IPPROTO_RAW = 255

  INET_ADDRSTRLEN  = 16
  INET6_ADDRSTRLEN = 46
end
