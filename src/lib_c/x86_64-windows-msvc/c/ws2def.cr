lib LibC
  alias ADDRESS_FAMILY = UShort

  AF_UNSPEC     = 0      # unspecified
  AF_UNIX       = 1      # local to host (pipes, portals)
  AF_INET       = 2      # internetwork: UDP, TCP, etc.
  AF_IMPLINK    = 3      # arpanet imp addresses
  AF_PUP        = 4      # pup protocols: e.g. BSP
  AF_CHAOS      = 5      # mit CHAOS protocols
  AF_NS         = 6      # XEROX NS protocols
  AF_IPX        = AF_NS  # IPX protocols: IPX, SPX, etc.
  AF_ISO        = 7      # ISO protocols
  AF_OSI        = AF_ISO # OSI is ISO
  AF_ECMA       =  8     # european computer manufacturers
  AF_DATAKIT    =  9     # datakit protocols
  AF_CCITT      = 10     # CCITT protocols, X.25 etc
  AF_SNA        = 11     # IBM SNA
  AF_DECnet     = 12     # DECnet
  AF_DLI        = 13     # Direct data link interface
  AF_LAT        = 14     # LAT
  AF_HYLINK     = 15     # NSC Hyperchannel
  AF_APPLETALK  = 16     # AppleTalk
  AF_NETBIOS    = 17     # NetBios-style addresses
  AF_VOICEVIEW  = 18     # VoiceView
  AF_FIREFOX    = 19     # Protocols from Firefox
  AF_UNKNOWN1   = 20     # Somebody is using this!
  AF_BAN        = 21     # Banyan
  AF_ATM        = 22     # Native ATM Services
  AF_INET6      = 23     # Internetwork Version 6
  AF_CLUSTER    = 24     # Microsoft Wolfpack
  AF_12844      = 25     # IEEE 1284.4 WG AF
  AF_IRDA       = 26     # IrDA
  AF_NETDES     = 28     # Network Designers OSI & gateway
  AF_TCNPROCESS = 29
  AF_TCNMESSAGE = 30
  AF_ICLFXBM    = 31
  AF_BTH        = 32 # Bluetooth RFCOMM/L2CAP protocols
  AF_LINK       = 33
  AF_HYPERV     = 34
  AF_MAX        = 35

  SOCK_STREAM    = 1
  SOCK_DGRAM     = 2
  SOCK_RAW       = 3
  SOCK_RDM       = 4
  SOCK_SEQPACKET = 5

  struct Sockaddr
    sa_family : UInt8
    sa_data : Char[14]
  end

  IPPROTO_IP = 0

  enum IPPROTO
    IPPROTO_HOPOPTS  =   0 # IPv6 Hop-by-Hop options
    IPPROTO_ICMP     =   1
    IPPROTO_IGMP     =   2
    IPPROTO_GGP      =   3
    IPPROTO_IPV4     =   4
    IPPROTO_ST       =   5
    IPPROTO_TCP      =   6
    IPPROTO_CBT      =   7
    IPPROTO_EGP      =   8
    IPPROTO_IGP      =   9
    IPPROTO_PUP      =  12
    IPPROTO_UDP      =  17
    IPPROTO_RDP      =  27
    IPPROTO_IPV6     =  41 # IPv6 header
    IPPROTO_ROUTING  =  43 # IPv6 Routing header
    IPPROTO_FRAGMENT =  44 # IPv6 fragmentation header
    IPPROTO_ESP      =  50 # encapsulating security payload
    IPPROTO_AH       =  51 # authentication header
    IPPROTO_ICMPV6   =  58 # ICMPv6
    IPPROTO_NONE     =  59 # IPv6 no next header
    IPPROTO_DSTOPTS  =  60 # IPv6 Destination options
    IPPROTO_ND       =  77
    IPPROTO_ICLFXBM  =  78
    IPPROTO_PIM      = 103
    IPPROTO_PGM      = 113
    IPPROTO_L2TP     = 115
    IPPROTO_SCTP     = 132
    IPPROTO_RAW      = 255
    IPPROTO_MAX      = 256
  end

  AI_PASSIVE     = 0x00000001 # Socket address will be used in bind() call
  AI_CANONNAME   = 0x00000002 # Return canonical name in first ai_canonname
  AI_NUMERICHOST = 0x00000004 # Nodename must be a numeric address string
  AI_NUMERICSERV = 0x00000008 # Servicename must be a numeric port number
  AI_DNS_ONLY    = 0x00000010 # Restrict queries to unicast DNS only (no LLMNR, netbios, etc.)

  AI_ALL        = 0x00000100 # Query both IP6 and IP4 with AI_V4MAPPED
  AI_ADDRCONFIG = 0x00000400 # Resolution only if global address configured
  AI_V4MAPPED   = 0x00000800 # On v6 failure, query v4 and convert to V4MAPPED format

  AI_NON_AUTHORITATIVE      = 0x00004000 # LUP_NON_AUTHORITATIVE
  AI_SECURE                 = 0x00008000 # LUP_SECURE
  AI_RETURN_PREFERRED_NAMES = 0x00010000 # LUP_RETURN_PREFERRED_NAMES

  AI_FQDN                 = 0x00020000 # Return the FQDN in ai_canonname
  AI_FILESERVER           = 0x00040000 # Resolving fileserver name resolution
  AI_DISABLE_IDN_ENCODING = 0x00080000 # Disable Internationalized Domain Names handling
  AI_EXTENDED             = 0x80000000 # Indicates this is extended ADDRINFOEX(2/..) struct
  AI_RESOLUTION_HANDLE    = 0x40000000 # Request resolution handle

  struct Addrinfo
    ai_flags : Int
    ai_family : Int
    ai_socktype : Int
    ai_protocol : Int
    ai_addrlen : SizeT
    ai_canonname : Char*
    ai_addr : Sockaddr*
    ai_next : Addrinfo*
  end
end
