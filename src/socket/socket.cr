require "./libc"
require "./addrinfo"

class SocketError < Exception
end

class Socket < FileDescriptorIO
  enum Type
    STREAM = LibC::SOCK_STREAM
    DGRAM  = LibC::SOCK_DGRAM
    RAW    = LibC::SOCK_RAW
  end

  enum Protocol
    IP  = LibC::IPPROTO_IP
    TCP = LibC::IPPROTO_TCP
    UDP = LibC::IPPROTO_UDP
    RAW = LibC::IPPROTO_RAW
  end

  enum Family : LibC::AddressFamilyType
    UNSPEC = LibC::AF_UNSPEC
    UNIX   = LibC::AF_UNIX
    INET   = LibC::AF_INET
    INET6  = LibC::AF_INET6
  end

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
