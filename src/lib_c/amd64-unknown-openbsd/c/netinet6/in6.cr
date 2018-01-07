require "../sys/socket"
require "../stdint"

lib LibC
  union In6AddrU6Addr
    __u6_addr8 : StaticArray(UInt8T, 16)
    __u6_addr16 : StaticArray(UInt16T, 8)
    __u6_addr32 : StaticArray(UInt32T, 4)
  end

  struct In6Addr
    __u6_addr : In6AddrU6Addr
  end

  struct SockaddrIn6
    sin6_len : UInt8T        # length of this struct(sa_family_t)
    sin6_family : SaFamilyT  # AF_INET6 (sa_family_t)
    sin6_port : InPortT      # Transport layer port # (in_port_t)
    sin6_flowinfo : UInt32T  # IP6 flow information
    sin6_addr : In6Addr      # IP6 address
    sin6_scope_id : UInt32T  # intface scope id
  end
end
