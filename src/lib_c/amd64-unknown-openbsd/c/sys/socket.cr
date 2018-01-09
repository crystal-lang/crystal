require "./types"

lib LibC
  alias SocklenT = UInt
  alias SaFamilyT = Char

  # Types
  SOCK_STREAM    = 1 # stream socket
  SOCK_DGRAM     = 2 # datagram socket
  SOCK_RAW       = 3 # raw-protocol interface
  SOCK_RDM       = 4 # reliably-delivered message
  SOCK_SEQPACKET = 5 # sequenced packet stream

  # Socket creation flags
  SOCK_CLOEXEC  = 0x8000
  SOCK_NONBLOCK = 0x4000
  SOCK_DNS      = 0x1000

  # Option flags
  SO_DEBUG       = 0x0001 # turn on debugging info recording
  SO_ACCEPTCONN  = 0x0002 # socket has had listen()
  SO_REUSEADDR   = 0x0004 # allow local address reuse
  SO_KEEPALIVE   = 0x0008 # keep connections alive
  SO_DONTROUTE   = 0x0010 # just use interface addresses
  SO_BROADCAST   = 0x0020 # permit sending of broadcast msgs
  SO_USELOOPBACK = 0x0040 # bypass hardware when possible
  SO_LINGER      = 0x0080 # linger on close if data present
  SO_OOBINLINE   = 0x0100 # leave received OOB data in line
  SO_REUSEPORT   = 0x0200 # allow local address & port reuse
  SO_TIMESTAMP   = 0x0800 # timestamp received dgram traffic
  SO_BINDANY     = 0x1000 # allow bind to any address
  SO_ZEROIZE     = 0x2000 # zero out all mbufs sent over socket

  SO_SNDBUF   = 0x1001 # send buffer size
  SO_RCVBUF   = 0x1002 # receive buffer size
  SO_SNDLOWAT = 0x1003 # send low-water mark
  SO_RCVLOWAT = 0x1004 # receive low-water mark
  SO_SNDTIMEO = 0x1005 # send timeout
  SO_RCVTIMEO = 0x1006 # receive timeout
  SO_ERROR    = 0x1007 # get error status and clear
  SO_TYPE     = 0x1008 # get socket type
  SO_NETPROC  = 0x1020 # multiplex; network processing
  SO_RTABLE   = 0x1021 # routing table to be used
  SO_PEERCRED = 0x1022 # get connect-time credentials
  SO_SPLICE   = 0x1023 # splice data to other socket

  struct Linger
    l_onoff : Int  # option on/off
    l_linger : Int # linger time
  end

  SOL_SOCKET = 0xffff # options for socket level

  # Address Families
  AF_UNSPEC          = 0              # unspecified
  AF_LOCAL           = 1              # local to host (pipes, portals)
  AF_UNIX            = LibC::AF_LOCAL # backward compatibility
  AF_INET            = 2              # internetwork: UDP, TCP, etc.
  AF_IMPLINK         = 3              # arpanet imp addresses
  AF_PUP             = 4              # pup protocols: e.g. BSP
  AF_CHAOS           = 5              # mit CHAOS protocols
  AF_NS              = 6              # XEROX NS protocols
  AF_ISO             = 7              # ISO protocols
  AF_OSI             = LibC::AF_ISO
  AF_ECMA            =  8            # european computer manufacturers
  AF_DATAKIT         =  9            # datakit protocols
  AF_CCITT           = 10            # CCITT protocols, X.25 etc
  AF_SNA             = 11            # IBM SNA
  AF_DECnet          = 12            # DECnet
  AF_DLI             = 13            # DEC Direct data link interface
  AF_LAT             = 14            # LAT
  AF_HYLINK          = 15            # NSC Hyperchannel
  AF_APPLETALK       = 16            # Apple Talk
  AF_ROUTE           = 17            # Internal Routing Protocol
  AF_LINK            = 18            # Link layer interface
  AF_XTP_pseudo      = 19            # eXpress Transfer Protocol (no AF)
  AF_COIP            = 20            # connection-oriented IP, aka ST II
  AF_CNT             = 21            # Computer Network Technology
  AF_RTIP_pseudo     = 22            # Help Identify RTIP packets
  AF_IPX             = 23            # Novell Internet Protocol
  AF_INET6           = 24            # IPv6
  AF_PIP_pseudo      = 25            # Help Identify PIP packets
  AF_ISDN            = 26            # Integrated Services Digital Networ
  AF_E164            = LibC::AF_ISDN # CCITT E.164 recommendation
  AF_NATM            = 27            # native ATM access
  AF_ENCAP           = 28
  AF_SIP             = 29 # Simple Internet Protocol
  AF_KEY             = 30
  AF_HDRCMPLT_pseudo = 31 # Used by BPF to not rewrite headers in interface output routine
  AF_BLUETOOTH       = 32 # Bluetooth
  AF_MPLS            = 33 # MPLS
  AF_PFLOW_pseudo    = 34 # pflow
  AF_PIPEX_pseudo    = 35 # PIPEX
  AF_MAX             = 36

  struct Sockaddr
    sa_len : Char                   # total length
    sa_family : SaFamilyT           # address family
    sa_data : StaticArray(Char, 14) # actually longer; address value
  end

  struct SockaddrStorage
    ss_len : UChar                     # total length
    ss_family : SaFamilyT              # address family
    __ss_pad1 : StaticArray(Char, 6)   # align to quad
    __ss_pad2 : ULongLong              # force alignment for stupid compilers
    __ss_pad3 : StaticArray(Char, 240) # pad to a total of 256 bytes
  end

  # Protocol Families
  PF_UNSPEC    = LibC::AF_UNSPEC
  PF_LOCAL     = LibC::AF_LOCAL
  PF_UNIX      = LibC::PF_LOCAL # backward compatibility
  PF_INET      = LibC::AF_INET
  PF_IMPLINK   = LibC::AF_IMPLINK
  PF_PUP       = LibC::AF_PUP
  PF_CHAOS     = LibC::AF_CHAOS
  PF_NS        = LibC::AF_NS
  PF_ISO       = LibC::AF_ISO
  PF_OSI       = LibC::AF_ISO
  PF_ECMA      = LibC::AF_ECMA
  PF_DATAKIT   = LibC::AF_DATAKIT
  PF_CCITT     = LibC::AF_CCITT
  PF_SNA       = LibC::AF_SNA
  PF_DECnet    = LibC::AF_DECnet
  PF_DLI       = LibC::AF_DLI
  PF_LAT       = LibC::AF_LAT
  PF_HYLINK    = LibC::AF_HYLINK
  PF_APPLETALK = LibC::AF_APPLETALK
  PF_ROUTE     = LibC::AF_ROUTE
  PF_LINK      = LibC::AF_LINK
  PF_XTP       = LibC::AF_XTP_pseudo # really just proto family, no AF
  PF_COIP      = LibC::AF_COIP
  PF_CNT       = LibC::AF_CNT
  PF_IPX       = LibC::AF_IPX # same format as AF_NS
  PF_INET6     = LibC::AF_INET6
  PF_RTIP      = LibC::AF_RTIP_pseudo # same format as AF_INET
  PF_PIP       = LibC::AF_PIP_pseudo
  PF_ISDN      = LibC::AF_ISDN
  PF_NATM      = LibC::AF_NATM
  PF_ENCAP     = LibC::AF_ENCAP
  PF_SIP       = LibC::AF_SIP
  PF_KEY       = LibC::AF_KEY
  PF_BPF       = LibC::AF_HDRCMPLT_pseudo
  PF_BLUETOOTH = LibC::AF_BLUETOOTH
  PF_MPLS      = LibC::AF_MPLS
  PF_PFLOW     = LibC::AF_PFLOW_pseudo
  PF_PIPEX     = LibC::AF_PIPEX_pseudo
  PF_MAX       = LibC::AF_MAX

  SHUT_RD   = 0
  SHUT_RDWR = 2
  SHUT_WR   = 1

  fun accept(s : Int, addr : Sockaddr*, addrlen : SocklenT*) : Int
  fun bind(s : Int, name : Sockaddr*, namelen : SocklenT) : Int
  fun connect(a : Int, name : Sockaddr*, namelen : SocklenT) : Int
  fun getpeername(s : Int, name : Sockaddr*, namelen : SocklenT*) : Int
  fun getsockname(s : Int, name : Sockaddr*, namelen : SocklenT*) : Int
  fun getsockopt(s : Int, level : Int, optname : Int, optval : Void*, optlen : SocklenT*) : Int
  fun listen(s : Int, backlog : Int) : Int
  fun recv(s : Int, buf : Void*, len : SizeT, flags : Int) : SSizeT
  fun recvfrom(s : Int, buf : Void*, len : SizeT, flags : Int, from : Sockaddr*, fromlen : SocklenT*) : SSizeT
  fun send(s : Int, msg : Void*, len : SizeT, flags : Int) : SSizeT
  fun sendto(s : Int, msg : Void*, len : SizeT, flags : Int, to : Sockaddr*, tolen : SocklenT) : SSizeT
  fun setsockopt(s : Int, level : Int, optname : Int, optval : Void*, optlen : SocklenT) : Int
  fun shutdown(s : Int, how : Int) : Int
  fun socket(domain : Int, type : Int, protocol : Int) : Int
  fun socketpair(d : Int, type : Int, protocol : Int, sv : StaticArray(Int, 2)) : Int
end
