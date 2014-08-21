lib C
  ifdef darwin
    struct SockAddrIn
      len : UInt8
      family : UInt8
      port : Int16
      addr : UInt32
      zero : Int64
    end

    AF_INET = 2_u8

    fun socket(domain : UInt8, t : Int32, protocol : Int32) : Int32
  else
    struct SockAddrIn
      family : UInt16
      port : Int16
      addr : UInt32
      zero : Int64
    end

    AF_INET = 2_u16

    fun socket(domain : UInt16, t : Int32, protocol : Int32) : Int32
  end

  struct HostEnt
    name : UInt8*
    aliases : UInt8**
    addrtype : Int32
    length : Int32
    addrlist : UInt8**
  end

  fun htons(n : Int32) : Int16
  fun bind(fd : Int32, addr : SockAddrIn*, addr_len : Int32) : Int32
  fun listen(fd : Int32, backlog : Int32) : Int32
  fun accept(fd : Int32, addr : SockAddrIn*, addr_len : Int32*) : Int32
  fun connect(fd : Int32, addr : SockAddrIn*, addr_len : Int32) : Int32
  fun gethostbyname(name : UInt8*) : HostEnt*
  fun setsockopt(sock : Int32, level : Int32, opt : Int32, optval : Void*, optlen : Int32) : Int32

  SOCK_STREAM = 1
  SOL_SOCKET = 0xffff
  SO_REUSEADDR = 0x0004
end

require "./*"
