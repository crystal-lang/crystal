require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE     =   1
  AI_CANONNAME   =   2
  AI_NUMERICHOST =   4
  AI_NUMERICSERV =  16
  AI_ADDRCONFIG  =  64
  EAI_AGAIN      =  -3
  EAI_BADFLAGS   =  -1
  EAI_FAIL       =  -4
  EAI_FAMILY     =  -6
  EAI_MEMORY     = -10
  EAI_NODATA     =  -5
  EAI_NONAME     =  -2
  EAI_SERVICE    =  -8
  EAI_SOCKTYPE   =  -7
  EAI_SYSTEM     = -11
  EAI_OVERFLOW   = -14

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SocklenT
    ai_addr : Void*
    ai_canonname : Char*
    ai_next : Addrinfo*
  end

  fun freeaddrinfo(x0 : Addrinfo*) : Void
  fun gai_strerror(x0 : Int) : Char*
  fun getaddrinfo(x0 : Char*, x1 : Char*, x2 : Addrinfo*, x3 : Addrinfo**) : Int
  fun getnameinfo(x0 : Void*, x1 : SocklenT, x2 : Char*, x3 : SizeT, x4 : Char*, x5 : SizeT, x6 : Int) : Int
end
