require "c/netdb"
require "c/netinet/in"
require "socket"

module DNS
  struct Addrinfo
    # :nodoc:
    INET6_ADDRSTRLEN = 46

    @[Flags]
    enum Flags
      PASSIVE     = LibC::AI_PASSIVE
      CANONNAME   = LibC::AI_CANONNAME
      NUMERICHOST = LibC::AI_NUMERICHOST
      NUMERICSERV = LibC::AI_NUMERICSERV
      V4MAPPED    = LibC::AI_V4MAPPED
      ALL         = LibC::AI_ALL
      ADDRCONFIG  = LibC::AI_ADDRCONFIG
    end

    class Error < Exception
      enum Code
        AGAIN    = LibC::EAI_AGAIN
        BADFLAGS = LibC::EAI_BADFLAGS
        FAIL     = LibC::EAI_FAIL
        FAMILY   = LibC::EAI_FAMILY
        MEMORY   = LibC::EAI_MEMORY
        NONAME   = LibC::EAI_NONAME
        SERVICE  = LibC::EAI_SERVICE
        SOCKTYPE = LibC::EAI_SOCKTYPE
        SYSTEM   = LibC::EAI_SYSTEM
        OVERFLOW = LibC::EAI_OVERFLOW
      end

      getter code : Code

      def initialize(@code : Code)
        super String.new(LibC.gai_strerror(code))
      end

      def self.new(code : Int32)
        new Code.new(code)
      end
    end

    getter family : Socket::Family
    getter type : Socket::Type
    getter protocol : Socket::Protocol
    getter port : Int32
    getter addr : StaticArray(UInt8, 16)

    def initialize(addrinfo : LibC::Addrinfo)
      @family = Socket::Family.from_value(addrinfo.ai_family)
      @type = Socket::Type.from_value(addrinfo.ai_socktype)
      @protocol = Socket::Protocol.from_value(addrinfo.ai_protocol)

      case family
      when Socket::Family::INET
        @port, @addr = from_sockaddr_in(addrinfo)
      when Socket::Family::INET6
        @port, @addr = from_sockaddr_in6(addrinfo)
      else
        raise ArgumentError.new("Expected INET or INET6 socket family but got #{family}")
      end
    end

    private def from_sockaddr_in(addrinfo)
      sa = addrinfo.ai_addr.as(LibC::SockaddrIn*).value
      port = LibC.ntohs(sa.sin_port).to_i32
      in_addr = sa.sin_addr
      ptr = pointerof(in_addr).as(UInt8*)
      addr = StaticArray(UInt8, 16).new { |i| i < 4 ? ptr[i] : 0_u8 }
      {port, addr}
    end

    private def from_sockaddr_in6(addrinfo)
      sa = addrinfo.ai_addr.as(LibC::SockaddrIn6*).value
      port = LibC.ntohs(sa.sin6_port).to_i32
      in_addr = sa.sin6_addr
      ptr = pointerof(in_addr).as(UInt8*)
      addr = StaticArray(UInt8, 16).new { |i| ptr[i] }
      {port, addr}
    end

    def to_unsafe
      case family
      when Socket::Family::INET
        to_sockaddr_in_pointer
      when Socket::Family::INET6
        to_sockaddr_in6_pointer
      else
        raise ArgumentError.new("Expected INET or INET6 socket family but got #{family}")
      end
    end

    private def to_sockaddr_in_pointer
      sa = LibC::SockaddrIn.new
      sa.sin_family = family
      sa.sin_port = LibC.htons(port)
      sa.sin_addr = addr_pointer.as(LibC::InAddr*).value
      pointerof(sa).as(LibC::Sockaddr*).value
    end

    private def to_sockaddr_in6_pointer
      sa = LibC::SockaddrIn6.new
      sa.sin6_family = family
      sa.sin6_port = LibC.htons(port)
      sa.sin6_addr = addr_pointer.as(LibC::In6Addr*).value
      pointerof(sa).as(LibC::Sockaddr*).value
    end

    private def addr_pointer
      Slice(UInt8).new(@addr.size) { |i| @addr[i] }.to_unsafe
    end

    def to_s(io)
      buf = uninitialized UInt8[INET6_ADDRSTRLEN]
      ret = LibC.inet_ntop(family, addr.to_unsafe.as(Void*), buf, INET6_ADDRSTRLEN)
      io << String.new(ret) unless ret.null?
    end

    def inspect(io)
      io << self.class.name << "(family="
      io << family
      io << ", type=" << type
      io << ", protocol=" << protocol
      io << ", port=" << port
      io << ", addr="
      to_s(io)
      io << ')'
    end
  end
end
