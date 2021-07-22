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

  struct In6Addr
    s6_addr : StaticArray(UChar, 16)
  end

  struct SockaddrIn
    sin_family : SaFamilyT
    sin_port : InPortT
    sin_addr : InAddr
  end

  struct SockaddrIn6
    sin6_family : SaFamilyT
    sin6_port : InPortT
    sin6_flowinfo : UInt
    sin6_addr : In6Addr
    sin6_scope_id : UInt
  end

  IP_MULTICAST_IF   = 32
  IPV6_MULTICAST_IF = 17

  IP_MULTICAST_TTL    = 33
  IPV6_MULTICAST_HOPS = 18

  IP_MULTICAST_LOOP   = 34
  IPV6_MULTICAST_LOOP = 19

  IP_ADD_MEMBERSHIP = 35
  IPV6_JOIN_GROUP   = 20

  IP_DROP_MEMBERSHIP = 36
  IPV6_LEAVE_GROUP   = 21

  struct IpMreq
    imr_multiaddr : InAddr
    imr_interface : InAddr
  end

  struct Ipv6Mreq
    ipv6mr_multiaddr : In6Addr
    ipv6mr_interface : UInt
  end
end
