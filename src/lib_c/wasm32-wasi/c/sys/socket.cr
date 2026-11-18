require "./types"

lib LibC
  SOCK_DGRAM    =       5_u8
  SOCK_STREAM   =       6_u8
  SOL_SOCKET    = 0x7fffffff
  AF_INET       =          1
  AF_INET6      =          2
  AF_UNIX       =          3
  AF_UNSPEC     =          0
  SHUT_RD       =       1_u8
  SHUT_RDWR     = SHUT_RD | SHUT_WR
  SHUT_WR       =       2_u8
  SOCK_CLOEXEC  = 0x00002000
  SOCK_NONBLOCK = 0x00004000

  {% unless flag?(:wasip1) %}
    SOL_TCP = 6

    SOMAXCONN = 128

    SO_REUSEADDR  =  2
    SO_ERROR      =  4
    SO_SNDBUF     =  7
    SO_RCVBUF     =  8
    SO_KEEPALIVE  =  9
    SO_ACCEPTCONN = 30
    SO_PROTOCOL   = 38
    SO_DOMAIN     = 39
    SO_RCVTIMEO   = 66
    SO_SNDTIMEO   = 67
  {% end %}

  alias SocklenT = UInt
  alias SaFamilyT = UShort

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : StaticArray(Char, 0)
  end

  struct SockaddrStorage
    ss_family : SaFamilyT
    __ss_data : StaticArray(Char, 32)
    # wasi-libc rounds socket address sizes to a 16-byte boundary.
    __padding : UInt8[14]
  end

  struct Linger
    l_onoff : Int
    l_linger : Int
  end

  fun accept(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*) : Int
  fun accept4(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*, x3 : Int) : Int
  fun getsockopt(x0 : Int, x1 : Int, x2 : Int, x3 : Void*, x4 : SocklenT*) : Int
  fun recv(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int) : SSizeT
  fun send(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int) : SSizeT
  fun shutdown(x0 : Int, x1 : Int) : Int

  {% unless flag?(:wasip1) %}
    fun bind(x0 : Int, x1 : Sockaddr*, x2 : SocklenT) : Int
    fun connect(x0 : Int, x1 : Sockaddr*, x2 : SocklenT) : Int
    fun getpeername(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*) : Int
    fun getsockname(x0 : Int, x1 : Sockaddr*, x2 : SocklenT*) : Int
    fun listen(x0 : Int, x1 : Int) : Int
    fun recvfrom(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int, x4 : Sockaddr*, x5 : SocklenT*) : SSizeT
    fun sendto(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int, x4 : Sockaddr*, x5 : SocklenT) : SSizeT
    fun setsockopt(x0 : Int, x1 : Int, x2 : Int, x3 : Void*, x4 : SocklenT) : Int
    fun socket(x0 : Int, x1 : Int, x2 : Int) : Int
  {% end %}
end
