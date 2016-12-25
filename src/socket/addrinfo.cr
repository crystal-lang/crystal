class Socket
  struct Addrinfo
    getter family : Family
    getter type : Type
    getter protocol : Protocol
    getter size : Int32

    @addr : LibC::SockaddrIn6
    @next : LibC::Addrinfo*

    def self.resolve(host, service, family : Family, type : Type, protocol : Protocol = Protocol::IP, timeout = nil)
      hints = LibC::Addrinfo.new
      hints.ai_family = (family || Family::UNSPEC).to_i32
      hints.ai_socktype = type
      hints.ai_protocol = protocol
      hints.ai_flags = 0

      if service.is_a?(Int)
        hints.ai_flags |= LibC::AI_NUMERICSERV
      end

      case ret = LibC.getaddrinfo(host, service.to_s, pointerof(hints), out ptr)
      when 0
        # success
      when LibC::EAI_NONAME
        raise Socket::Error.new("No address found for #{host}:#{service} over #{protocol}")
      else
        raise Socket::Error.new("getaddrinfo: #{String.new(LibC.gai_strerror(ret))}")
      end

      begin
        addrinfo = new(ptr)
        error = nil

        loop do
          error = yield addrinfo.not_nil!
          return unless error

          unless addrinfo = addrinfo.try(&.next?)
            if error.is_a?(Errno) && error.errno == Errno::ECONNREFUSED
              raise Errno.new("Error connecting to '#{host}:#{service}'", error.errno)
            else
              raise error if error
            end
          end
        end
      ensure
        LibC.freeaddrinfo(ptr)
      end
    end

    def self.tcp(host, service, family = Family::UNSPEC, timeout = nil)
      resolve(host, service, family, Type::STREAM, Protocol::TCP) { |addrinfo| yield addrinfo }
    end

    def self.udp(host, service, family = Family::UNSPEC, timeout = nil)
      resolve(host, service, family, Type::DGRAM, Protocol::UDP) { |addrinfo| yield addrinfo }
    end

    protected def initialize(addrinfo : LibC::Addrinfo*)
      @family = Family.from_value(addrinfo.value.ai_family)
      @type = Type.from_value(addrinfo.value.ai_socktype)
      @protocol = Protocol.from_value(addrinfo.value.ai_protocol)
      @size = addrinfo.value.ai_addrlen.to_i

      @addr = uninitialized LibC::SockaddrIn6
      @next = addrinfo.value.ai_next

      case @family
      when Family::INET6
        addrinfo.value.ai_addr.as(LibC::SockaddrIn6*).copy_to(pointerof(@addr).as(LibC::SockaddrIn6*), 1)
      when Family::INET
        addrinfo.value.ai_addr.as(LibC::SockaddrIn*).copy_to(pointerof(@addr).as(LibC::SockaddrIn*), 1)
      end
    end

    def ip_address
      @ip_address = IPAddress.from(@addr, @addrlen)
    end

    def to_unsafe
      pointerof(@addr).as(LibC::Sockaddr*)
    end

    protected def next?
      if addrinfo = @next
        Addrinfo.new(addrinfo)
      end
    end
  end
end
