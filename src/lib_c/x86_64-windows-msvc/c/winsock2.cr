require "./ws2def"

@[Link("WS2_32")]
lib LibC
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

  fun WSASetLastError(iError : Int) : Void
  fun WSAGetLastError : Int
end
