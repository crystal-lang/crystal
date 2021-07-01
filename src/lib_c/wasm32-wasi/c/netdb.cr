require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE     =  0x01
  AI_CANONNAME   =  0x02
  AI_NUMERICHOST =  0x04
  AI_NUMERICSERV = 0x400
  AI_V4MAPPED    =  0x08
  AI_ALL         =  0x10
  AI_ADDRCONFIG  =  0x20
  EAI_AGAIN      =    -3
  EAI_BADFLAGS   =    -1
  EAI_FAIL       =    -4
  EAI_FAMILY     =    -6
  EAI_MEMORY     =   -10
  EAI_NONAME     =    -2
  EAI_SERVICE    =    -8
  EAI_SOCKTYPE   =    -7
  EAI_SYSTEM     =   -11
  EAI_OVERFLOW   =   -12

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SocklenT
    ai_addr : Sockaddr*
    ai_canonname : Char*
    ai_next : Addrinfo*
  end

  fun freeaddrinfo(x0 : Addrinfo*) : Void
  fun gai_strerror(x0 : Int) : Char*
  fun getaddrinfo(x0 : Char*, x1 : Char*, x2 : Addrinfo*, x3 : Addrinfo**) : Int
  fun getnameinfo(x0 : Sockaddr*, x1 : SocklenT, x2 : Char*, x3 : SocklenT, x4 : Char*, x5 : SocklenT, x6 : Int) : Int
end
