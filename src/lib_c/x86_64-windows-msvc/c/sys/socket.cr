require "./types"
require "./un"

@[Link("WS2_32")]
lib LibC
  alias SocklenT = Int
  alias SaFamilyT = UShort
  alias SOCKET = UInt

  SO_REUSEADDR = 0x0004
  SO_BROADCAST = 0x0020
  SOL_SOCKET   = 0xFFFF

  # -2147195266 is the value after convertion to long, actual value 2147772030 with type unsigned
  FIONBIO = -2147195266

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : StaticArray(UInt8, 14)
  end

  alias SOCKADDR = Sockaddr

  struct WSAData
    vVersion : WORD
    wHighVersion : WORD
    szDescription : StaticArray(UInt8, 257)
    szSystemStatus : StaticArray(UInt8, 129)
    iMaxSockets : UInt16
    iMaxUdpDg : UInt16
    lpVendorInfo : UInt8*
  end

  struct SockaddrStorage
    ss_family : Short
    __ss_pad1 : StaticArray(Char, 6)
    __ss_align : Int64
    __ss_pad2 : StaticArray(Char, 112)
  end

  alias LPWSADATA = WSAData*

  fun wsastartup = WSAStartup(wVersionRequired : WORD, lpWSAData : LPWSADATA) : Int
  fun socket(af : Int, type : Int, protocol : Int) : SOCKET
  fun bind(s : SOCKET, addr : Sockaddr*, namelen : Int) : Int
  fun closesocket(s : SOCKET) : Int
  fun send(s : SOCKET, buf : UInt8*, len : Int, flags : Int) : Int
  fun setsockopt(s : SOCKET, level : Int, optname : Int, optval : UInt8*, len : Int) : Int
  fun ioctlsocket(s : SOCKET, cmd : Int, argp : UInt32*) : Int
  fun listen(s : SOCKET, backlog : Int) : Int
  fun accept(s : SOCKET, addr : Sockaddr*, addrlen : Int*) : SOCKET
  fun getpeername(s : SOCKET, name : Sockaddr*, namelen : Int*) : Int
  fun ntohs(netshort : UShort) : UShort
  fun recv(s : SOCKET, buf : UInt8*, len : Int, flags : Int) : Int
  fun connect(s : SOCKET, name : Sockaddr*, namelen : Int) : Int
  fun getsockname(s : SOCKET, name : Sockaddr*, namelen : Int*) : Int
  fun htons(hostshort : UShort) : UShort
  fun getsockopt(s : SOCKET, level : Int, optname : Int, optval : UInt8*, optlen : Int*) : Int
  fun sendto(s : SOCKET, buf : UInt8*, len : Int, flags : Int, to : Sockaddr*, tolen : Int) : Int
  fun recvfrom(s : SOCKET, buf : Char*, len : Int, flags : Int, from : Sockaddr*, fromlen : Int*) : Int

  SO_RCVBUF           = 0x1002
  TCP_NODELAY         = 0x0001
  TCP_KEEPIDLE        =      3
  TCP_KEEPCNT         =     16
  TCP_KEEPINTVL       =     17
  IP_MULTICAST_LOOP   =     11
  IPV6_MULTICAST_LOOP =     11
  IPPROTO_IPV6        =     41
  IP_MULTICAST_TTL    =     10
  IP_MULTICAST_IF     =      9
  IPV6_MULTICAST_IF   =      9
  IPV6_MULTICAST_HOPS =     10
  IP_ADD_MEMBERSHIP   =     12
end

# TODO
wsadata = uninitialized LibC::WSAData
wsaVersion = 514
LibC.wsastartup(wsaVersion, pointerof(wsadata))
