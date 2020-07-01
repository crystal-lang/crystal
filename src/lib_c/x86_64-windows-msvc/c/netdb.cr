# DIFF
# require "./netinet/in"
# require "./stdint"
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

  # lin
  AI_NUMERICSERV = 0x0400

  # move to sys/socket
  AF_UNSPEC    =  0
  AF_INET      =  2
  AF_IPX       =  6
  AF_APPLETALK = 16
  AF_NETBIOS   = 17
  AF_INET6     = 23
  AF_IRDA      = 26
  AF_BTH       = 32

  # lin
  PF_INET   =  2
  PF_INET6  = 10
  PF_UNIX   = LibC::PF_LOCAL
  PF_UNSPEC = 0
  PF_LOCAL  = 1
  AF_UNIX   = LibC::PF_UNIX

  # # lin
  EAI_AGAIN    =  -3
  EAI_BADFLAGS =  -1
  EAI_FAIL     =  -4
  EAI_FAMILY   =  -6
  EAI_MEMORY   = -10
  EAI_NONAME   =  -2
  EAI_SERVICE  =  -8
  EAI_SOCKTYPE =  -7
  EAI_SYSTEM   = -11
  EAI_OVERFLOW = -12

  # move to sys/socket
  SOCK_STREAM    = 1
  SOCK_DGRAM     = 2
  SOCK_RAW       = 3
  SOCK_RDM       = 4
  SOCK_SEQPACKET = 5

  # move to netinet/in
  IPPROTO_TCP  =   6
  IPPROTO_UDP  =  17
  IPPROTO_RM   = 113
  IPPROTO_IGMP =   2
  # ipcp
  BTHPROTO_RFCOMM =  3
  IPPROTO_ICMPV6  = 58

  # # lin
  IPPROTO_IP   =   0
  IPPROTO_RAW  = 255
  IPPROTO_ICMP =   1

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SizeT
    ai_canonname : UInt8*
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
