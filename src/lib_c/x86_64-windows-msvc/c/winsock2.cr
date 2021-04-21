require "./ws2def"

@[Link("WS2_32")]
lib LibC
  AF_UNSPEC    =  0
  AF_UNIX      =  1
  AF_INET      =  2
  AF_IPX       =  6
  AF_APPLETALK = 16
  AF_NETBIOS   = 17
  AF_INET6     = 23
  AF_IRDA      = 26
  AF_BTH       = 32

  SOCK_STREAM    = 1
  SOCK_DGRAM     = 2
  SOCK_RAW       = 3
  SOCK_RDM       = 4
  SOCK_SEQPACKET = 5

  struct InAddr
    s_addr : UInt32
  end

  struct WSAData
    wVersion : WORD
    wHighVersion : WORD
    szDescription : Char[257]
    szSystemStatus : Char[129]
    iMaxSockets : UInt16
    iMaxUdpDg : UInt16
    lpVendorInfo : Char*
  end

  fun htons(hostshort : UShort) : UShort
  fun ntohs(netshort : UShort) : UShort
  fun WSAStartup(wVersionRequired : WORD, lpWSAData : WSAData*) : Int
end
