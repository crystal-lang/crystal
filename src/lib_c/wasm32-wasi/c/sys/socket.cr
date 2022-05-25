require "./types"

lib LibC
  SOCK_DGRAM   =       5_u8
  SOCK_STREAM  =       6_u8
  SOL_SOCKET   = 0x7fffffff
  AF_INET      =          1
  AF_INET6     =          2
  AF_UNIX      =          3
  AF_UNSPEC    =          0
  SHUT_RD      =       1_u8
  SHUT_RDWR    = SHUT_RD | SHUT_WR
  SHUT_WR      =       2_u8
  SOCK_CLOEXEC = 0x00002000

  alias SocklenT = UInt
  alias SaFamilyT = UShort

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : StaticArray(Char, 0)
  end

  struct SockaddrStorage
    ss_family : SaFamilyT
    __ss_data : StaticArray(Char, 32)
  end

  struct Linger
    l_onoff : Int
    l_linger : Int
  end

  fun getsockopt(x0 : Int, x1 : Int, x2 : Int, x3 : Void*, x4 : SocklenT*) : Int
  fun recv(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int) : SSizeT
  fun send(x0 : Int, x1 : Void*, x2 : SizeT, x3 : Int) : SSizeT
  fun shutdown(x0 : Int, x1 : Int) : Int
end
