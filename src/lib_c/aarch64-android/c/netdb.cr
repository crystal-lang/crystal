require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE     = 0x0001
  AI_CANONNAME   = 0x0002
  AI_NUMERICHOST = 0x0004
  AI_NUMERICSERV = 0x0008
  AI_V4MAPPED    = 0x0800
  AI_ALL         = 0x0100
  AI_ADDRCONFIG  = 0x0400
  EAI_AGAIN      =      2
  EAI_BADFLAGS   =      3
  EAI_FAIL       =      4
  EAI_FAMILY     =      5
  EAI_MEMORY     =      6
  EAI_NODATA     =      7
  EAI_NONAME     =      8
  EAI_SERVICE    =      9
  EAI_SOCKTYPE   =     10
  EAI_SYSTEM     =     11
  EAI_OVERFLOW   =     14

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

  fun freeaddrinfo(__ptr : Addrinfo*)
  fun gai_strerror(__error : Int) : Char*
  fun getaddrinfo(__node : Char*, __service : Char*, __hints : Addrinfo*, __result : Addrinfo**) : Int
  fun getnameinfo(__sa : Sockaddr*, __sa_length : SocklenT, __host : Char*, __host_length : SizeT, __service : Char*, __service_length : SizeT, __flags : Int) : Int
end
