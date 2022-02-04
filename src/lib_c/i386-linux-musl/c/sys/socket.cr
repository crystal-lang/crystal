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
  AF_UNIX        = LibC::AF_LOCAL
  AF_UNSPEC      = LibC::PF_UNSPEC
  AF_LOCAL       = LibC::PF_LOCAL
  SHUT_RD        =         0
  SHUT_RDWR      =         2
  SHUT_WR        =         1
  SOCK_CLOEXEC   = 0o2000000

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

  fun accept(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*) : Int
  fun bind(x0 : Int, x1 : Sockaddr*, x2 : SocklenT) : Int
  fun connect(x0 : Int, x1 : Sockaddr*, x2 : SocklenT) : Int
  fun getpeername(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*) : Int
  fun getsockname(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*) : Int
  fun getsockopt(x0 : Int, x1 : Int, x2 : Int, x3 : Void*, x4 : SocklenT*) : Int
  fun listen(x0 : Int, x1 : Int) : Int
  fun recv(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int) : SSizeT
  fun recvfrom(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int, x4 : Sockaddr*, x5 : SocklenT*) : SSizeT
  fun send(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int) : SSizeT
  fun sendto(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int, x4 : Sockaddr*, x5 : SocklenT) : SSizeT
  fun setsockopt(x0 : Int, x1 : Int, x2 : Int, x3 : Void*, x4 : SocklenT) : Int
  fun shutdown(x0 : Int, x1 : Int) : Int
  fun socket(x0 : Int, x1 : Int, x2 : Int) : Int
  fun socketpair(x0 : Int, x1 : Int, x2 : Int, x3 : StaticArray(Int, 2)) : Int
end
