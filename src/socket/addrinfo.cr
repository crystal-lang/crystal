class Socket
  # Domain name resolver.
  struct Addrinfo
    getter family : Family
    getter type : Type
    getter protocol : Protocol
    getter size : Int32

    @addr : LibC::SockaddrIn6
    @next : LibC::Addrinfo*

    # Resolves a domain that best matches the given options.
    #
    # - *domain* may be an IP address or a domain name.
    # - *service* may be a port number or a service name. It must be specified,
    #   because different servers may handle the `mail` or `http` services for
    #   example.
    # - *family* is optional and defaults to `Family::UNSPEC`
    # - *type* is the intented socket type (e.g. `Type::STREAM`) and must be
    #   specified.
    # - *protocol* is the intented socket protocol (e.g. `Protocol::TCP`) and
    #   should be specified.
    #
    # Each possible resolution will be yield as an `Addrinfo` struct, for as
    # long as the block returns an error. The iteration will stop once the block
    # returns `nil`.
    #
    # Example:
    # ```
    # Socket::Addrinfo.resolve("example.org", "http", type: Socket::Type::STREAM, protocol: Socket::Type::TCP) do |addrinfo|
    #   sock = Socket.new(addrinfo.family, addrinfo.type, addrinfo.protocol)
    #   sock.connect(addrinfo)
    #   return sock
    # end
    # ```
    def self.resolve(domain, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil)
      hints = LibC::Addrinfo.new
      hints.ai_family = (family || Family::UNSPEC).to_i32
      hints.ai_socktype = type
      hints.ai_protocol = protocol
      hints.ai_flags = 0

      if service.is_a?(Int)
        hints.ai_flags |= LibC::AI_NUMERICSERV
      end

      case ret = LibC.getaddrinfo(domain, service.to_s, pointerof(hints), out ptr)
      when 0
        # success
      when LibC::EAI_NONAME
        raise Socket::Error.new("No address found for #{domain}:#{service} over #{protocol}")
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
              raise Errno.new("Error connecting to '#{domain}:#{service}'", error.errno)
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
    # Shortcut to resolve a domain for the TCP protocol with STREAM type.
    #
    # Example:
    # ```
    # Addrinfo.tcp("example.org", 80) do |addrinfo|
    #   sock = Socket.new(addrinfo.family, addrinfo.type, addrinfo.protocol)
    #   sock.connect(addrinfo)
    #   sock
    # end
    # ```
    def self.tcp(domain, service, family = Family::UNSPEC, timeout = nil)
      resolve(domain, service, family, Type::STREAM, Protocol::TCP) { |addrinfo| yield addrinfo }
    end

    end

    # Shortcut to resolve a domain for the UDP protocol with DGRAM type.
    #
    # Example:
    # ```
    # sock = UDPSocket.new
    # Addrinfo.udp("example.org", 53) do |addrinfo|
    #   sock.bind(addrinfo)
    #   sock
    # end
    # ```
    def self.udp(domain, service, family = Family::UNSPEC, timeout = nil)
      resolve(domain, service, family, Type::DGRAM, Protocol::UDP) { |addrinfo| yield addrinfo }
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

    # Returns an `IPAddress` matching this addrinfo.
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
