require "./types"

lib LibC
  SOCK_DGRAM     =  2
  SOCK_RAW       =  3
  SOCK_SEQPACKET =  5
  SOCK_STREAM    =  1
  SOL_SOCKET     =  1
  SO_BROADCAST   =  6
  SO_KEEPALIVE   =  9
  SO_LINGER      = 13
  SO_RCVBUF      =  8
  SO_REUSEADDR   =  2
  SO_REUSEPORT   = 15
  SO_SNDBUF      =  7
  PF_INET        =  2
  PF_INET6       = 10
  PF_UNIX        = LibC::PF_LOCAL
  PF_UNSPEC      = 0
  PF_LOCAL       = 1
  AF_INET        = LibC::PF_INET
  AF_INET6       = LibC::PF_INET6
  AF_UNIX        = LibC::PF_UNIX
  AF_UNSPEC      = LibC::PF_UNSPEC
  AF_LOCAL       = LibC::PF_LOCAL
  SHUT_RD        =      0
  SHUT_RDWR      =      2
  SHUT_WR        =      1
  SOCK_CLOEXEC   = 524288

  alias SocklenT = UInt
  alias SaFamilyT = UShort

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : StaticArray(Char, 14)
  end

  struct SockaddrStorage
    ss_family : SaFamilyT
    __ss_align : ULong
    __ss_padding : StaticArray(Char, 112)
  end

  struct Linger
    l_onoff : Int
    l_linger : Int
  end

  fun accept(fd : Int, addr : Sockaddr*, addr_len : SocklenT*) : Int
  fun bind(fd : Int, addr : Sockaddr*, len : SocklenT) : Int
  fun connect(fd : Int, addr : Sockaddr*, len : SocklenT) : Int
  fun getpeername(fd : Int, addr : Sockaddr*, len : SocklenT*) : Int
  fun getsockname(fd : Int, addr : Sockaddr*, len : SocklenT*) : Int
  fun getsockopt(fd : Int, level : Int, optname : Int, optval : Void*, optlen : SocklenT*) : Int
  fun listen(fd : Int, n : Int) : Int
  fun recv(fd : Int, buf : Void*, n : SizeT, flags : Int) : SSizeT
  fun recvfrom(fd : Int, buf : Void*, n : SizeT, flags : Int, addr : Sockaddr*, addr_len : SocklenT*) : SSizeT
  fun send(fd : Int, buf : Void*, n : SizeT, flags : Int) : SSizeT
  fun sendto(fd : Int, buf : Void*, n : SizeT, flags : Int, addr : Sockaddr*, addr_len : SocklenT) : SSizeT
  fun setsockopt(fd : Int, level : Int, optname : Int, optval : Void*, optlen : SocklenT) : Int
  fun shutdown(fd : Int, how : Int) : Int
  fun socket(domain : Int, type : Int, protocol : Int) : Int
  fun socketpair(domain : Int, type : Int, protocol : Int, fds : StaticArray(Int, 2)) : Int
end
