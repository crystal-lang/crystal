lib LibC
  IPPROTO_IP     =   0
  IPPROTO_ICMP   =   1
  IPPROTO_IGMP   =   2
  IPPROTO_TCP    =   6
  IPPROTO_UDP    =  17
  IPPROTO_ICMPV6 =  58
  IPPROTO_RAW    = 255

  struct Sockaddr
    sa_family : UInt8
    sa_data : Char[14]
  end
end
