require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE     = 0x00000001
  AI_CANONNAME   = 0x00000002
  AI_NUMERICHOST = 0x00000004
  AI_NUMERICSERV = 0x00001000
  AI_V4MAPPED    = 0x00000800
  AI_ALL         = 0x00000100
  AI_ADDRCONFIG  = 0x00000400
  EAI_AGAIN      =          2
  EAI_BADFLAGS   =          3
  EAI_FAIL       =          4
  EAI_FAMILY     =          5
  EAI_MEMORY     =          6
  EAI_NONAME     =          8
  EAI_SERVICE    =          9
  EAI_SOCKTYPE   =         10
  EAI_SYSTEM     =         11
  EAI_OVERFLOW   =         14

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SocklenT
    ai_canonname : Char*
    ai_addr : Sockaddr*
    ai_next : Addrinfo*
  end

  fun freeaddrinfo(x0 : Addrinfo*) : Void
  fun gai_strerror(x0 : Int) : Char*
  fun getaddrinfo(x0 : Char*, x1 : Char*, x2 : Addrinfo*, x3 : Addrinfo**) : Int
  fun getnameinfo(x0 : Sockaddr*, x1 : SocklenT, x2 : Char*, x3 : SocklenT, x4 : Char*, x5 : SocklenT, x6 : Int) : Int
end
