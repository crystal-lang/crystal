require "../sys/socket"
require "../stdint"

lib LibC
  IPPROTO_IP   =   0
  IPPROTO_IPV6 =  41
  IPPROTO_ICMP =   1
  IPPROTO_RAW  = 255
  IPPROTO_TCP  =   6
  IPPROTO_UDP  =  17

  alias BE16 = UInt16
  alias BE32 = UInt32
  alias InAddrT = UInt32

  struct InAddr
    s_addr : InAddrT
  end

  union In6AddrIn6U
    __u6_addr8 : UInt8[16]
    __u6_addr16 : BE16[8]
    __u6_addr32 : BE32[4]
  end

  struct In6Addr
    __in6_u : In6AddrIn6U
  end

  struct SockaddrIn
    sin_family : UShort
    sin_port : BE16
    sin_addr : InAddr
    sin_zero : UChar[8] # __SOCK_SIZE__ (16) - ...
  end

  struct SockaddrIn6
    sin6_family : UShort
    sin6_port : BE16
    sin6_flowinfo : BE32
    sin6_addr : In6Addr
    sin6_scope_id : UInt32
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
    ipv6mr_ifindex : Int
  end
end
