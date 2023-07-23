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
  PF_INET        = LibC::AF_INET
  PF_INET6       = LibC::AF_INET6
  PF_UNIX        = LibC::AF_UNIX
  PF_UNSPEC      = LibC::AF_UNSPEC
  PF_LOCAL       = LibC::AF_LOCAL
  AF_INET        =         2
  AF_INET6       =        10
  AF_UNIX        =         1
  AF_UNSPEC      =         0
  AF_LOCAL       =         1
  SHUT_RD        =         0
  SHUT_RDWR      =         2
  SHUT_WR        =         1
  SOCK_CLOEXEC   = 0o2000000

  alias SocklenT = UInt32
  alias SaFamilyT = UShort

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : Char[14]
  end

  struct SockaddrStorage
    ss_family : SaFamilyT
    __align : Void*
    __data : Char[112]
  end

  struct Linger
    l_onoff : Int
    l_linger : Int
  end

  fun accept(__fd : Int, __addr : Sockaddr*, __addr_length : SocklenT*) : Int
  fun bind(__fd : Int, __addr : Sockaddr*, __addr_length : SocklenT) : Int
  fun connect(__fd : Int, __addr : Sockaddr*, __addr_length : SocklenT) : Int
  fun getpeername(__fd : Int, __addr : Sockaddr*, __addr_length : SocklenT*) : Int
  fun getsockname(__fd : Int, __addr : Sockaddr*, __addr_length : SocklenT*) : Int
  fun getsockopt(__fd : Int, __level : Int, __option : Int, __value : Void*, __value_length : SocklenT*) : Int
  fun listen(__fd : Int, __backlog : Int) : Int
  fun recv(__fd : Int, __buf : Void*, __n : SizeT, __flags : Int) : SSizeT
  fun recvfrom(__fd : Int, __buf : Void*, __n : SizeT, __flags : Int, __src_addr : Sockaddr*, __src_addr_length : SocklenT*) : SSizeT
  fun send(__fd : Int, __buf : Void*, __n : SizeT, __flags : Int) : SSizeT
  fun sendto(__fd : Int, __buf : Void*, __n : SizeT, __flags : Int, __dst_addr : Sockaddr*, __dst_addr_length : SocklenT) : SSizeT
  fun setsockopt(__fd : Int, __level : Int, __option : Int, __value : Void*, __value_length : SocklenT) : Int
  fun shutdown(__fd : Int, __how : Int) : Int
  fun socket(__af : Int, __type : Int, __protocol : Int) : Int
  fun socketpair(__af : Int, __type : Int, __protocol : Int, __fds : Int[2]) : Int
end
