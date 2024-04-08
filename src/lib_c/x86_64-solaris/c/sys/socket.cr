require "./types"

@[Link("socket")]
lib LibC
  SOCK_DGRAM     =      1
  SOCK_RAW       =      4
  SOCK_SEQPACKET =      6
  SOCK_STREAM    =      2
  SOL_SOCKET     = 0xffff
  SO_BROADCAST   = 0x0020
  SO_KEEPALIVE   = 0x0008
  SO_LINGER      = 0x0080
  SO_RCVBUF      = 0x1002
  SO_REUSEADDR   = 0x0004
  SO_REUSEPORT   = 0x2004
  SO_SNDBUF      = 0x1001
  PF_INET        = LibC::AF_INET
  PF_INET6       = LibC::AF_INET6
  PF_UNIX        = LibC::AF_UNIX
  PF_UNSPEC      = LibC::AF_UNSPEC
  PF_LOCAL       = LibC::PF_UNIX
  AF_INET        =  2
  AF_INET6       = 26
  AF_UNIX        =  1
  AF_UNSPEC      =  0
  AF_LOCAL       = LibC::AF_UNIX
  SHUT_RD        =        0
  SHUT_RDWR      =        2
  SHUT_WR        =        1
  SOCK_CLOEXEC   = 0x080000

  alias SocklenT = UInt32
  alias SaFamilyT = UInt16

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : Char[14]
  end

  struct SockaddrStorage
    ss_family : SaFamilyT
    _ss_pad1 : Char[6] # sizeof(Double) - sizeof(SaFamilyT)
    _ss_align : Double
    _ss_pad2 : Char[240] # SS_MAXSIZE (256) - sizeof(SaFamilyT) - sizeof(typeof(_ss_align)) - sizeof(Double)
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
