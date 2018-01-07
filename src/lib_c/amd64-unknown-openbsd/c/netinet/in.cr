require "../sys/socket"
require "../stdint"

lib LibC
  alias InAddrT = UInt    # __uint32_t <sys/_types.h>
  alias InPortT = UShort  # __uint16_t <sys/_types.h>

  # Protocols
  IPPROTO_IP        =   0  # dummy for IP
  IPPROTO_HOPOPTS   = IPPROTO_IP  # Hop-by-hop option header
  IPPROTO_ICMP      =   1  # control message protocol
  IPPROTO_IGMP      =   2  # group mgmt protocol
  IPPROTO_GGP       =   3  # gateway^2 (deprecated)
  IPPROTO_IPIP      =   4  # IP inside IP
  IPPROTO_IPV4      = IPPROTO_IPIP  # IP inside IP
  IPPROTO_TCP       =   6  # tcp
  IPPROTO_EGP       =   8  # exterior gateway protocol
  IPPROTO_PUP       =  12  # pup
  IPPROTO_UDP       =  17  # user datagram protocol
  IPPROTO_IDP       =  22  # xns idp
  IPPROTO_TP        =  29  # tp-4 w/ class negotiation
  IPPROTO_IPV6      =  41  # IPv6 in IPv6
  IPPROTO_ROUTING   =  43  # Routing header
  IPPROTO_FRAGMENT  =  44  # Fragmentation/reassembly header
  IPPROTO_RSVP      =  46  # resource reservation
  IPPROTO_GRE       =  47  # GRE encap, RFCs 1701/1702
  IPPROTO_ESP       =  50  # Encap. Security Payload
  IPPROTO_AH        =  51  # Authentication header
  IPPROTO_MOBILE    =  55  # IP Mobility, RFC 2004
  IPPROTO_ICMPV6    =  58  # ICMP for IPv6
  IPPROTO_NONE      =  59  # No next header
  IPPROTO_DSTOPTS   =  60  # Destination options header
  IPPROTO_EON       =  80  # ISO cnlp
  IPPROTO_ETHERIP   =  97  # Ethernet in IPv4
  IPPROTO_ENCAP     =  98  # encapsulation header
  IPPROTO_PIM       = 103  # Protocol indep. multicast
  IPPROTO_IPCOMP    = 108  # IP Payload Comp. Protocol
  IPPROTO_CARP      = 112  # CARP
  IPPROTO_MPLS      = 137  # unicast MPLS packet
  IPPROTO_PFSYNC    = 240  # PFSYNC
  IPPROTO_RAW       = 255  # raw IP packet
  IPPROTO_MAX       = 256

  struct InAddr
    s_addr : InAddrT
  end

  union In6AddrU6Addr
    __u6_addr8 : StaticArray(UInt8T, 16)
    __u6_addr16 : StaticArray(UInt16T, 8)
    __u6_addr32 : StaticArray(UInt32T, 4)
  end

  struct In6Addr
    __u6_addr : In6AddrU6Addr
  end

  struct SockaddrIn
    sin_len : UInt8T
    sin_family : SaFamilyT
    sin_port : InPortT
    sin_addr : InAddr
    sin_zero : StaticArray(Int8T, 8)
  end

  struct SockaddrIn6
    sin6_len : UInt8T
    sin6_family : SaFamilyT
    sin6_port : InPortT
    sin6_flowinfo : UInt32T
    sin6_addr : In6Addr
    sin6_scope_id : UInt32T
  end
end
