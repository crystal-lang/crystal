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

  TCP_EXPEDITED_1122       = 0x0002
  TCP_KEEPALIVE            =      3
  TCP_MAXSEG               =      4
  TCP_MAXRT                =      5
  TCP_STDURG               =      6
  TCP_NOURG                =      7
  TCP_ATMARK               =      8
  TCP_NOSYNRETRIES         =      9
  TCP_TIMESTAMPS           =     10
  TCP_OFFLOAD_PREFERENCE   =     11
  TCP_CONGESTION_ALGORITHM =     12
  TCP_DELAY_FIN_ACK        =     13
  TCP_MAXRTMS              =     14
  TCP_FASTOPEN             =     15
  TCP_KEEPCNT              =     16
  TCP_KEEPIDLE             = TCP_KEEPALIVE
  TCP_KEEPINTVL            = 17
end
