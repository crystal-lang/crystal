require "./types"

@[Link("WS2_32")]
lib LibC
  alias SocklenT = Int
  alias SaFamilyT = UShort
  alias SOCKET = UInt

  SO_REUSEADDR = 0x0004
  SO_BROADCAST = 0x0020
  SOL_SOCKET = 0xFFFF

  # -2147195266 is the value after convertion to long, actual value 2147772030 with type unsigned
  FIONBIO = -2147195266

  struct Sockaddr
    sa_family : SaFamilyT
    sa_data : StaticArray(UInt8, 14)
  end

  alias SOCKADDR = Sockaddr

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
end
