require "../sys/socket"
require "../stdint"

lib LibC
  IPPROTO_IP   =   0
  IPPROTO_IPV6 =  41
  IPPROTO_ICMP =   1
  IPPROTO_RAW  = 255
  IPPROTO_TCP  =   6
  IPPROTO_UDP  =  17

  alias InPortT = UInt16
  alias InAddrT = UInt32

  struct InAddr
    s_addr : InAddrT # actually a union similar to `In6AddrS6Un`
  end

  union In6AddrS6Un
    _S6_u8 : UInt8[16]
    _S6_u16 : UInt16[8]
    _S6_u32 : UInt32[4]
    __S6_align : UInt32
  end

  struct In6Addr
    _S6_un : In6AddrS6Un
  end

  struct SockaddrIn
    sin_family : SaFamilyT
    sin_port : InPortT
    sin_addr : InAddr
    sin_zero : Char[8]
  end

  struct SockaddrIn6
    sin6_family : SaFamilyT
    sin6_port : InPortT
    sin6_flowinfo : UInt32
    sin6_addr : In6Addr
    sin6_scope_id : UInt32
    __sin6_src_id : UInt32
  end

  IP_MULTICAST_IF   = 0x10
  IPV6_MULTICAST_IF =  0x6

  IP_MULTICAST_TTL    = 0x11
  IPV6_MULTICAST_HOPS =  0x7

  IP_MULTICAST_LOOP   = 0x12
  IPV6_MULTICAST_LOOP =  0x8

  IP_ADD_MEMBERSHIP = 0x13
  IPV6_JOIN_GROUP   =  0x9

  IP_DROP_MEMBERSHIP = 0x14
  IPV6_LEAVE_GROUP   =  0xa

  struct IpMreq
    imr_multiaddr : InAddr
    imr_interface : InAddr
  end

  struct Ipv6Mreq
    ipv6mr_multiaddr : In6Addr
    ipv6mr_interface : UInt
  end
end
