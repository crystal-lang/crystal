require "../sys/socket"
require "../stdint"

lib LibC
  IPPROTO_IP   =   0
  IPPROTO_IPV6 =  41
  IPPROTO_ICMP =   1
  IPPROTO_RAW  = 255
  IPPROTO_TCP  =   6
  IPPROTO_UDP  =  17

  alias InPortT = UShort
  alias InAddrT = UInt

  struct InAddr
    s_addr : InAddrT
  end

  union In6AddrU6Addr
    __u6_addr8 : StaticArray(SaFamilyT, 16)
    __u6_addr16 : StaticArray(UShort, 8)
    __u6_addr32 : StaticArray(UInt, 4)
  end

  struct In6Addr
    __u6_addr : In6AddrU6Addr
  end

  struct SockaddrIn
    sin_len : SaFamilyT
    sin_family : SaFamilyT
    sin_port : InPortT
    sin_addr : InAddr
    sin_zero : StaticArray(Char, 8)
  end

  struct SockaddrIn6
    sin6_len : SaFamilyT
    sin6_family : SaFamilyT
    sin6_port : InPortT
    sin6_flowinfo : UInt
    sin6_addr : In6Addr
    sin6_scope_id : UInt
  end

  IP_MULTICAST_IF   = 9
  IPV6_MULTICAST_IF = 9

  IP_MULTICAST_TTL    = 10
  IPV6_MULTICAST_HOPS = 10

  IP_MULTICAST_LOOP   = 11
  IPV6_MULTICAST_LOOP = 11

  IP_ADD_MEMBERSHIP = 12
  IPV6_JOIN_GROUP   = 12

  IP_DROP_MEMBERSHIP = 13
  IPV6_LEAVE_GROUP   = 13

  struct IpMreq
    imr_multiaddr : InAddr
    imr_interface : InAddr
  end

  struct Ipv6Mreq
    ipv6mr_multiaddr : In6Addr
    ipv6mr_interface : UInt
  end
end
