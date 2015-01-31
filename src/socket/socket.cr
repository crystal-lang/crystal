lib LibC
  ifdef darwin
    struct SockAddrIn
      len : UInt8
      family : UInt8
      port : Int16
      addr : UInt32
      zero : Int64
    end

    struct SockAddrIn6
      len : UInt8
      family : UInt8
      port : Int16
      flowinfo : Int32
      addr : StaticArray(UInt8, 16)
      scope_id : UInt32
    end

    struct SockAddrUn
      len : UInt8
      family : UInt8
      path : UInt8*
    end

    struct SockAddr
      len : UInt8
      family : UInt8
      data : StaticArray(UInt8, 14)
    end

    AF_UNSPEC = 0_u8
    AF_UNIX = 1_u8
    AF_INET = 2_u8
    AF_INET6 = 30_u8

    SOL_SOCKET = 0xffff
    SO_REUSEADDR = 0x0004

    fun socket(domain : UInt8, t : Int32, protocol : Int32) : Int32
    fun socketpair(domain : UInt8, t : Int32, protocol : Int32, sockets : StaticArray(Int32, 2)*) : Int32
    fun inet_pton(af : UInt8, src : UInt8*, dst : Void*) : Int32
    fun inet_ntop(af : UInt8, src : Void*, dst : UInt8*, size : Int32) : UInt8*
  else
    struct SockAddrIn
      family : UInt16
      port : Int16
      addr : UInt32
      zero : Int64
    end

    struct SockAddrIn6
      family : UInt16
      port : Int16
      flowinfo : Int32
      addr : StaticArray(UInt8, 16)
      scope_id : UInt32
    end

    struct SockAddrUn
      family : UInt16
      path : UInt8*
    end

    struct SockAddr
      family : UInt16
      data : StaticArray(UInt8, 14)
    end

    AF_UNSPEC = 0_u16
    AF_UNIX = 1_u16
    AF_INET = 2_u16
    AF_INET6 = 10_u16

    SOL_SOCKET = 1
    SO_REUSEADDR = 2

    fun socket(domain : UInt16, t : Int32, protocol : Int32) : Int32
    fun socketpair(domain : UInt16, t : Int32, protocol : Int32, sockets : StaticArray(Int32, 2)*) : Int32
    fun inet_pton(af : UInt16, src : UInt8*, dst : Void*) : Int32
    fun inet_ntop(af : UInt16, src : Void*, dst : UInt8*, size : Int32) : UInt8*
  end

  struct HostEnt
    name : UInt8*
    aliases : UInt8**
    addrtype : Int32
    length : Int32
    addrlist : UInt8**
  end

  fun htons(n : Int32) : Int16
  fun bind(fd : Int32, addr : SockAddr*, addr_len : Int32) : Int32
  fun listen(fd : Int32, backlog : Int32) : Int32
  fun accept(fd : Int32, addr : SockAddr*, addr_len : Int32*) : Int32
  fun connect(fd : Int32, addr : SockAddr*, addr_len : Int32) : Int32
  fun gethostbyname(name : UInt8*) : HostEnt*
  fun getsockname(fd : Int32, addr : SockAddr*, addr_len : Int32*) : Int32
  fun getpeername(fd : Int32, addr : SockAddr*, addr_len : Int32*) : Int32
  fun setsockopt(sock : Int32, level : Int32, opt : Int32, optval : Void*, optlen : Int32) : Int32

  SOCK_STREAM = 1
  SOCK_DGRAM = 2
  SOCK_RAW = 3

  IPPROTO_IP = 0
  IPPROTO_TCP = 6
  IPPROTO_UDP = 17
  IPPROTO_RAW = 255

  INET_ADDRSTRLEN = 16
  INET6_ADDRSTRLEN = 46
end

class SocketError < Exception
end

class Socket < FileDescriptorIO
  struct Addr
    property :family, :ip_port, :ip_address, :path

    def initialize(@family, @ip_port, @ip_address)
    end

    def initialize(@family, @path)
    end
  end

  def afamily(family)
    LibC::AF_UNSPEC.class.cast(family)
  end

  def inspect(io)
    io << "#<#{self.class}:fd #{@fd}>"
  end

  def self.inet_ntop(sa : LibC::SockAddrIn6)
    ip_address = GC.malloc_atomic(LibC::INET6_ADDRSTRLEN.to_u32) as UInt8*
    addr = sa.addr
    LibC.inet_ntop(LibC::AF_INET6, pointerof(addr) as Void*, ip_address, LibC::INET6_ADDRSTRLEN)
    String.new(ip_address)
  end

  def self.inet_ntop(sa : LibC::SockAddrIn)
    ip_address = GC.malloc_atomic(LibC::INET_ADDRSTRLEN.to_u32) as UInt8*
    addr = sa.addr
    LibC.inet_ntop(LibC::AF_INET, pointerof(addr) as Void*, ip_address, LibC::INET_ADDRSTRLEN)
    String.new(ip_address)
  end
end

require "./*"
