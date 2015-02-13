require "./libc"

lib LibC
  ifdef darwin
    struct Addrinfo
      flags : Int32
      family : Int32
      socktype : Int32
      protocol : Int32
      addrlen : Int32
      canonname : UInt8*
      addr : SockAddr*
      next : Addrinfo*
    end
  else
    struct Addrinfo
      flags : Int32
      family : Int32
      socktype : Int32
      protocol : Int32
      addrlen : Int32
      addr : SockAddr*
      canonname : UInt8*
      next : Addrinfo*
    end
  end

  fun freeaddrinfo(addr : Addrinfo*) : Void
  fun gai_strerror(code : Int32) : UInt8*
  fun getaddrinfo(name : UInt8*, service : UInt8*, hints : Addrinfo*, pai : Addrinfo**) : Int32
  fun getnameinfo(addr : SockAddr*, addrlen : Int32, host : UInt8*, hostlen : Int32, serv : UInt8*, servlen : Int32, flags : Int32) : Int32

  AI_PASSIVE = 0x0001
  AI_CANONNAME = 0x0002
  AI_NUMERICHOST = 0x0004
  AI_V4MAPPED = 0x0008
  AI_ALL = 0x0010
  AI_ADDRCONFIG = 0x0020

  NI_MAXHOST = 1025
  NI_MAXSERV = 32

  NI_NUMERICHOST = 1
  NI_NUMERICSERV = 2
  NI_NOFQDN = 4
  NI_NAMEREQD = 8
  NI_DGRAM = 16
end
