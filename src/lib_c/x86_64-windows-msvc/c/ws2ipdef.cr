require "./in6addr"

lib LibC
  struct SockaddrIn6
    sin6_family : Short
    sin6_port : UShort
    sin6_flowinfo : ULong
    sin6_addr : In6Addr
    sin6_scope_id : ULong
  end

  struct SockaddrIn
    sin_family : Short
    sin_port : UShort
    sin_addr : InAddr
    sin_zero : StaticArray(CHAR, 8)
  end
end
