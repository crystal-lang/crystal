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

  struct InAddr
    s_addr : UInt32
  end

  fun htons(hostshort : UShort) : UShort
  fun ntohs(netshort : UShort) : UShort
end
