require "../sys/socket"
require "../winnt.cr"

lib LibC
  IPPROTO_IP     =   0
  IPPROTO_ICMP   =   1
  IPPROTO_IGMP   =   2
  IPPROTO_TCP    =   6
  IPPROTO_UDP    =  17
  IPPROTO_ICMPV6 =  58
  IPPROTO_RAW    = 255

  struct SUnB
    s_b1 : UCHAR
    s_b2 : UCHAR
    s_b3 : UCHAR
    s_b4 : UCHAR
  end

  struct SUnW
    s_w1 : USHORT
    s_w2 : USHORT
  end

  union InAddrU
    s_un_b : SUnB
    s_un_w : SUnW
    s_addr : ULONG
  end

  struct InAddr
    s_un : InAddrU
  end

  union In6AddrIn6U
    byte : StaticArray(UCHAR, 16)
    word : StaticArray(USHORT, 8)
  end

  struct In6Addr
    u : In6AddrIn6U
  end

  struct SockaddrIn6
    sin6_family : SHORT
    sin6_port : USHORT
    sin6_flowinfo : ULONG
    sin6_addr : In6Addr
    sin6_scope_id : ULONG
  end

  struct SockaddrIn
    sin_family : SHORT
    sin_port : USHORT
    sin_addr : InAddr
    sin_zero : StaticArray(CHAR, 8)
  end
end
