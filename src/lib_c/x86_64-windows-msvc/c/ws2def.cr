lib LibC
  IPPROTO_IP     =   0
  IPPROTO_ICMP   =   1
  IPPROTO_IGMP   =   2
  IPPROTO_TCP    =   6
  IPPROTO_UDP    =  17
  IPPROTO_ICMPV6 =  58
  IPPROTO_RAW    = 255

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

  struct Sockaddr
    sa_family : UInt8
    sa_data : Char[14]
  end

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
end
