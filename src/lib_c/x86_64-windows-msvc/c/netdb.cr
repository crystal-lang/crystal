require "./sys/socket"

lib LibC
  AI_PASSIVE                =     0x0001
  AI_CANONNAME              =     0x0002
  AI_NUMERICHOST            =     0x0004
  AI_ALL                    =     0x0100
  AI_ADDRCONFIG             =     0x0400
  AI_V4MAPPED               =     0x0800
  AI_NON_AUTHORITATIVE      =    0x04000
  AI_SECURE                 =    0x08000
  AI_RETURN_PREFERRED_NAMES =   0x010000
  AI_FQDN                   = 0x00020000
  AI_FILESERVER             = 0x00040000
  AI_NUMERICSERV            = 0x00000008

  EAI_AGAIN    = 11002
  EAI_BADFLAGS = 10022
  EAI_FAIL     = 11003
  EAI_FAMILY   = 10047
  EAI_MEMORY   =     8
  EAI_NONAME   = 11001
  EAI_SERVICE  = 10109
  EAI_SOCKTYPE = 10044

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SizeT
    ai_canonname : Char*
    ai_addr : Sockaddr*
    ai_next : Addrinfo*
  end

  alias ADDRINFOA = Addrinfo
  alias PADDRINFOA = Addrinfo*

  fun freeaddrinfo(pAddrInfo : PADDRINFOA) : VOID
  fun getaddrinfo(pNodeName : PCSTR, pServiceName : PCSTR, pHints : ADDRINFOA*, ppResult : PADDRINFOA*) : INT
  fun getnameinfo(pSockaddr : SOCKADDR*, sockaddrLength : SocklenT, pNodeBuffer : PCHAR, nodeBufferSize : DWORD, pServiceBuffer : PCHAR, serviceBufferSize : DWORD, flags : INT) : INT

  # fun gai_strerror = gai_strerrorA(ecode : Int) : UInt8*
  # See src/socket/addrinfo.cr for `gai_strerrorA` function definition
end
