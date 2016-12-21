class Socket
  abstract struct Address
    getter family : Family
    getter size : Int32

    def self.from(sockaddr : LibC::Sockaddr*, addrlen) : Address
      case family = Family.new(sockaddr.value.sa_family)
      when Family::INET6
        IPAddress.new(sockaddr.as(LibC::SockaddrIn6*), addrlen.to_i)
      when Family::INET
        IPAddress.new(sockaddr.as(LibC::SockaddrIn*), addrlen.to_i)
      when Family::UNIX
        UNIXAddress.new(sockaddr.as(LibC::SockaddrUn*), addrlen.to_i)
      else
        raise "unsupported family type: #{family} (#{family.value})"
      end
    end

    def initialize(@family : Family, @size : Int32)
    end

    abstract def to_unsafe : LibC::Sockaddr*

    def ==(other)
      false
    end
  end

  struct IPAddress < Address
    getter port : Int32

    @address : String?
    @addr6 : LibC::In6Addr?
    @addr4 : LibC::InAddr?

    def initialize(@address : String, @port : Int32)
      if @addr6 = ip6?(address)
        @family = Family::INET6
        @size = sizeof(LibC::SockaddrIn6)
      elsif @addr4 = ip4?(address)
        @family = Family::INET
        @size = sizeof(LibC::SockaddrIn)
      else
        raise Error.new("Invalid IP address: #{address}")
      end
    end

    def self.from(sockaddr : LibC::Sockaddr*, addrlen) : IPAddress
      case family = Family.new(sockaddr.value.sa_family)
      when Family::INET6
        new(sockaddr.as(LibC::SockaddrIn6*), addrlen.to_i)
      when Family::INET
        new(sockaddr.as(LibC::SockaddrIn*), addrlen.to_i)
      else
        raise "unsupported family type: #{family} (#{family.value})"
      end
    end

    protected def initialize(sockaddr : LibC::SockaddrIn6*, @size)
      @family = Family::INET6
      @addr6 = sockaddr.value.sin6_addr
      @port = LibC.ntohs(sockaddr.value.sin6_port).to_i
    end

    protected def initialize(sockaddr : LibC::SockaddrIn*, @size)
      @family = Family::INET
      @addr4 = sockaddr.value.sin_addr
      @port = LibC.ntohs(sockaddr.value.sin_port).to_i
    end

    private def ip6?(address)
      addr = uninitialized LibC::In6Addr
      addr if LibC.inet_pton(LibC::AF_INET6, address, pointerof(addr)) == 1
    end

    private def ip4?(address)
      addr = uninitialized LibC::InAddr
      addr if LibC.inet_pton(LibC::AF_INET, address, pointerof(addr)) == 1
    end

    def address
      @address ||= begin
        case family
        when Family::INET6 then chars = address(@addr6)
        when Family::INET  then chars = address(@addr4)
        else                    raise "unsupported IP address family: #{family}"
        end
        raise Errno.new("Failed to convert IP address") unless chars
        String.new(chars)
      end
    end

    private def address(addr : LibC::In6Addr)
      chars = GC.malloc_atomic(46).as(UInt8*)
      chars if LibC.inet_ntop(family, pointerof(addr).as(Void*), chars, 46)
    end

    private def address(addr : LibC::InAddr)
      chars = GC.malloc_atomic(16).as(UInt8*)
      chars if LibC.inet_ntop(family, pointerof(addr).as(Void*), chars, 16)
    end

    private def address(addr) : Nil
      # shouldn't happen
    end

    def ==(other : IPAddress)
      family == other.family &&
        port == other.port &&
        address == other.address
    end

    def to_s(io)
      if family == Family::INET6
        io << '[' << address << ']' << ':' << port
      else
        io << address << ':' << port
      end
    end

    def to_unsafe : LibC::Sockaddr*
      case family
      when Family::INET6
        to_sockaddr_in6
      when Family::INET
        to_sockaddr_in
      else
        raise "unsupported IP address family: #{family}"
      end
    end

    private def to_sockaddr_in6
      sockaddr = Pointer(LibC::SockaddrIn6).malloc
      sockaddr.value.sin6_family = family
      sockaddr.value.sin6_port = LibC.htons(port)
      sockaddr.value.sin6_addr = @addr6.not_nil!
      sockaddr.as(LibC::Sockaddr*)
    end

    private def to_sockaddr_in
      sockaddr = Pointer(LibC::SockaddrIn).malloc
      sockaddr.value.sin_family = family
      sockaddr.value.sin_port = LibC.htons(port)
      sockaddr.value.sin_addr = @addr4.not_nil!
      sockaddr.as(LibC::Sockaddr*)
    end
  end

  struct UNIXAddress < Address
    getter path : String

    # :nodoc:
    MAX_PATH_SIZE = LibC::SockaddrUn.new.sun_path.size - 1

    def initialize(@path : String)
      if @path.bytesize + 1 > MAX_PATH_SIZE
        raise ArgumentError.new("Path size exceeds the maximum size of #{MAX_PATH_SIZE} bytes")
      end
      @family = Family::UNIX
      @size = sizeof(LibC::SockaddrUn)
    end

    def self.from(sockaddr : LibC::Sockaddr*, addrlen) : UNIXAddress
      new(sockaddr.as(LibC::SockaddrUn*), addrlen.to_i)
    end

    protected def initialize(sockaddr : LibC::SockaddrUn*, size)
      @family = Family::UNIX
      @path = String.new(sockaddr.value.sun_path.to_unsafe)
      @size = size || sizeof(LibC::SockaddrUn)
    end

    def ==(other : UNIXAddress)
      path == other.path
    end

    def to_s(io)
      io << path
    end

    def to_unsafe : LibC::Sockaddr*
      sockaddr = Pointer(LibC::SockaddrUn).malloc
      sockaddr.value.sun_family = family
      sockaddr.value.sun_path.to_unsafe.copy_from(@path.to_unsafe, @path.bytesize + 1)
      sockaddr.as(LibC::Sockaddr*)
    end
  end
end
