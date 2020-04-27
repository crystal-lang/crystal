require "./types"

lib LibC
  SOCK_DGRAM     =      2
  SOCK_RAW       =      3
  SOCK_SEQPACKET =      5
  SOCK_STREAM    =      1
  SOL_SOCKET     = 0xffff
  SO_BROADCAST   = 0x0020
  SO_KEEPALIVE   = 0x0008
  SO_LINGER      = 0x0080
  SO_RCVBUF      = 0x1002
  SO_REUSEADDR   = 0x0004
  SO_REUSEPORT   = 0x0200
  SO_SNDBUF      = 0x1001
  PF_INET        = LibC::AF_INET
  PF_INET6       = LibC::AF_INET6
  PF_UNIX        = LibC::PF_LOCAL
  PF_UNSPEC      = LibC::AF_UNSPEC
  PF_LOCAL       = LibC::AF_LOCAL
  AF_INET        =  2
  AF_INET6       = 30
  AF_UNIX        =  1
  AF_UNSPEC      =  0
  AF_LOCAL       = LibC::AF_UNIX
  SHUT_RD        = 0
  SHUT_RDWR      = 2
  SHUT_WR        = 1

  alias SocklenT = UInt
  alias SaFamilyT = Char

  struct Sockaddr
    sa_len : SaFamilyT
    sa_family : SaFamilyT
    sa_data : StaticArray(Char, 14)
  end

  struct SockaddrStorage
    ss_len : SaFamilyT
    ss_family : SaFamilyT
    __ss_pad1 : StaticArray(Char, 6)
    __ss_align : LongLong
    __ss_pad2 : StaticArray(Char, 112)
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
  fun socketpair(x0 : Int, x1 : Int, x2 : Int, x3 : Int*) : Int
end
