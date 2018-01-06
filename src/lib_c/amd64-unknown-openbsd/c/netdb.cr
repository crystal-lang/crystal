require "./netinet/in"
require "./sys/socket"
require "./stdint"

lib LibC
  AI_PASSIVE      =   1 # socket address is intended for bind()
  AI_CANONNAME    =   2 # request for canonical name
  AI_NUMERICHOST  =   4 # don't ever try hostname lookup
  AI_EXT          =   8 # enable non-portable extensions
  AI_NUMERICSERV  =  16 # don't ever try servname lookup
  AI_FQDN         =  32 # return the FQDN that was resolved
  AI_ADDRCONFIG   =  64 # return configured address families only
  AI_MASK         = (AI_PASSIVE|AI_CANONNAME|AI_NUMERICHOST|AI_NUMERICSERV|AI_FQDN|AI_ADDRCONFIG)

  EAI_BADFLAGS    =  -1 # invalid value for ai_flags
  EAI_NONAME      =  -2 # name or service is not known
  EAI_AGAIN       =  -3 # temporary failure in name resolution
  EAI_FAIL        =  -4 # non-recoverable failure in name resolution
  EAI_NODATA      =  -5 # no address associated with name
  EAI_FAMILY      =  -6 # ai_family not supported
  EAI_SOCKTYPE    =  -7 # ai_socktype not supported
  EAI_SERVICE     =  -8 # service not supported for ai_socktype
  EAI_ADDRFAMILY  =  -9 # address family for name not supported
  EAI_MEMORY      = -10 # memory allocation failure
  EAI_SYSTEM      = -11 # system error (code indicated in errno)
  EAI_BADHINTS    = -12 # invalid value for hints
  EAI_PROTOCOL    = -13 # resolved protocol is unknown
  EAI_OVERFLOW    = -14 # argument buffer overflow

  struct Addrinfo
    ai_flags : Int        # input flags
    ai_family : Int       # protocol family for socket
    ai_socktype : Int     # socket type
    ai_protocol : Int     # protocol for socket
    ai_addrlen : SocklenT # length of socket-address
    ai_addr : Void*       # socket-address for socket
    ai_canonname : Char*  # canonical name for service location (iff req)
    ai_next : Addrinfo*   # pointer to next in list
  end

  fun freeaddrinfo(x0 : Addrinfo*) : Void
  fun gai_strerror(x0 : Int) : Char*
  fun getaddrinfo(x0 : Char*, x1 : Char*, x2 : Addrinfo*, x3 : Addrinfo**) : Int
  fun getnameinfo(x0 : Void*, x1 : SocklenT, x2 : Char*, x3 : SizeT, x4 : Char*, x5 : SizeT, x6 : Int) : Int
end
