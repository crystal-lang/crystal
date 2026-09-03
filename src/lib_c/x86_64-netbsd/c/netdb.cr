require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE     =   0x1
  AI_CANONNAME   =   0x2
  AI_NUMERICHOST =   0x4
  AI_NUMERICSERV =   0x8
  AI_ADDRCONFIG  = 0x400
  EAI_AGAIN      =     2
  EAI_BADFLAGS   =     3
  EAI_FAIL       =     4
  EAI_FAMILY     =     5
  EAI_MEMORY     =     6
  EAI_NODATA     =     7
  EAI_NONAME     =     8
  EAI_SERVICE    =     9
  EAI_SOCKTYPE   =    10
  EAI_SYSTEM     =    11
  EAI_OVERFLOW   =    14

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SocklenT
    ai_canonname : Char*
    ai_addr : Void*
    ai_next : Addrinfo*
  end

  fun freeaddrinfo(x0 : Addrinfo*) : Void
  fun gai_strerror(x0 : Int) : Char*
  fun getaddrinfo(x0 : Char*, x1 : Char*, x2 : Addrinfo*, x3 : Addrinfo**) : Int
  fun getnameinfo(x0 : Void*, x1 : SocklenT, x2 : Char*, x3 : SizeT, x4 : Char*, x5 : SizeT, x6 : Int) : Int
end
