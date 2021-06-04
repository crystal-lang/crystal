require "./in6addr"
require "./inaddr"

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

  TCP_KEEPALIVE =  3
  TCP_KEEPCNT   = 16
  TCP_KEEPINTVL = 17
  TCP_KEEPIDLE  = TCP_KEEPALIVE
end
