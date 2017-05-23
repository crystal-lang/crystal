require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE     = 0x0001
  AI_CANONNAME   = 0x0002
  AI_NUMERICHOST = 0x0004
  AI_NUMERICSERV = 0x0400
  AI_V4MAPPED    = 0x0008
  AI_ALL         = 0x0010
  AI_ADDRCONFIG  = 0x0020
  EAI_AGAIN      =     -3
  EAI_BADFLAGS   =     -1
  EAI_FAIL       =     -4
  EAI_FAMILY     =     -6
  EAI_MEMORY     =    -10
  EAI_NONAME     =     -2
  EAI_SERVICE    =     -8
  EAI_SOCKTYPE   =     -7
  EAI_SYSTEM     =    -11
  EAI_OVERFLOW   =    -12

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

  fun freeaddrinfo(ai : Addrinfo*) : Void
  fun gai_strerror(ecode : Int) : Char*
  fun getaddrinfo(name : Char*, service : Char*, req : Addrinfo*, pai : Addrinfo**) : Int
  fun getnameinfo(sa : Sockaddr*, salen : SocklenT, host : Char*, hostlen : SocklenT, serv : Char*, servlen : SocklenT, flags : Int) : Int
end
