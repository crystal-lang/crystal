require "../sys/socket"
require "../stdint"

lib LibC
  IPPROTO_IP   =   0
  IPPROTO_ICMP =   1
  IPPROTO_RAW  = 255
  IPPROTO_TCP  =   6
  IPPROTO_UDP  =  17

  struct InAddr
    s_addr : UInt
  end

  union In6Addrin6U
    u6_addr8 : StaticArray(UChar, 16)
    u6_addr16 : StaticArray(UShort, 8)
    u6_addr32 : StaticArray(UInt, 4)
  end

  struct In6Addr
    in6_u : In6Addrin6U
  end

  struct SockaddrIn
    sin_family : UShort
    sin_port : UShort
    sin_addr : InAddr
    __pad : StaticArray(Char, 8)
  end

  struct SockaddrIn6
    sin6_family : UShort
    sin6_port : UShort
    sin6_flowinfo : UInt
    sin6_addr : In6Addr
    sin6_scope_id : UInt
  end
end
