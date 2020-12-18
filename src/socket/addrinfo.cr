require "uri/punycode"

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
    # - *type* is the intended socket type (e.g. `Type::STREAM`) and must be
    #   specified.
    # - *protocol* is the intended socket protocol (e.g. `Protocol::TCP`) and
    #   should be specified.
    #
    # Example:
    # ```
    # require "socket"
    #
    # addrinfos = Socket::Addrinfo.resolve("example.org", "http", type: Socket::Type::STREAM, protocol: Socket::Protocol::TCP)
    # ```
    def self.resolve(domain, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil) : Array(Addrinfo)
      addrinfos = [] of Addrinfo

      getaddrinfo(domain, service, family, type, protocol, timeout) do |addrinfo|
        loop do
          addrinfos << addrinfo.not_nil!
          unless addrinfo = addrinfo.next?
            return addrinfos
          end
        end
      end
    end

    # Resolves a domain that best matches the given options.
    #
    # Yields each possible `Addrinfo` resolution since a domain may resolve to
    # many IP. Implementations are supposed to try all the addresses until the
    # socket is connected (or bound) or there are no addresses to try anymore.
    #
    # Raising is an expensive operation, so instead of raising on a connect or
    # bind error, just to rescue it immediately after, the block is expected to
    # return the error instead, which will be raised once there are no more
    # addresses to try.
    #
    # The iteration will be stopped once the block returns something that isn't
    # an `Exception` (e.g. a `Socket` or `nil`).
    def self.resolve(domain, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil)
      getaddrinfo(domain, service, family, type, protocol, timeout) do |addrinfo|
        error = nil

        loop do
          value = yield addrinfo.not_nil!

          if value.is_a?(Exception)
            error = value
          else
            return value
          end

          unless addrinfo = addrinfo.try(&.next?)
            if error.is_a?(Socket::ConnectError)
              raise Socket::ConnectError.from_errno("Error connecting to '#{domain}:#{service}'")
            else
              raise error if error
            end
          end
        end
      end
    end

    class Error < Socket::Error
      getter error_code : Int32

      def self.new(error_code, domain)
        new error_code, String.new(LibC.gai_strerror(error_code)), domain
      end

      def initialize(@error_code, message, domain)
        super("Hostname lookup for #{domain} failed: #{message}")
      end
    end

    private def self.getaddrinfo(domain, service, family, type, protocol, timeout)
      # RFC 3986 says:
      # > When a non-ASCII registered name represents an internationalized domain name
      # > intended for resolution via the DNS, the name must be transformed to the IDNA
      # > encoding [RFC3490] prior to name lookup.
      domain = URI::Punycode.to_ascii domain

      hints = LibC::Addrinfo.new
      hints.ai_family = (family || Family::UNSPEC).to_i32
      hints.ai_socktype = type
      hints.ai_protocol = protocol
      hints.ai_flags = 0

      if service.is_a?(Int)
        hints.ai_flags |= LibC::AI_NUMERICSERV
      end

      # On OS X < 10.12, the libsystem implementation of getaddrinfo segfaults
      # if AI_NUMERICSERV is set, and servname is NULL or 0.
      {% if flag?(:darwin) %}
        if (service == 0 || service == nil) && (hints.ai_flags & LibC::AI_NUMERICSERV)
          hints.ai_flags |= LibC::AI_NUMERICSERV
          service = "00"
        end
      {% end %}

      case ret = LibC.getaddrinfo(domain, service.to_s, pointerof(hints), out ptr)
      when 0
        # success
      when LibC::EAI_NONAME
        raise Error.new(ret, "No address found", domain)
      when LibC::EAI_SOCKTYPE
        raise Error.new(ret, "The requested socket type #{type} protocol #{protocol} is not supported", domain)
      when LibC::EAI_SERVICE
        raise Error.new(ret, "The requested service #{service} is not available for the requested socket type #{type}", domain)
      else
        raise Error.new(ret, domain)
      end

      begin
        yield new(ptr)
      ensure
        LibC.freeaddrinfo(ptr)
      end
    end

    # Resolves *domain* for the TCP protocol and returns an `Array` of possible
    # `Addrinfo`. See `#resolve` for details.
    #
    # Example:
    # ```
    # require "socket"
    #
    # addrinfos = Socket::Addrinfo.tcp("example.org", 80)
    # ```
    def self.tcp(domain, service, family = Family::UNSPEC, timeout = nil) : Array(Addrinfo)
      resolve(domain, service, family, Type::STREAM, Protocol::TCP)
    end

    # Resolves a domain for the TCP protocol with STREAM type, and yields each
    # possible `Addrinfo`. See `#resolve` for details.
    def self.tcp(domain, service, family = Family::UNSPEC, timeout = nil)
      resolve(domain, service, family, Type::STREAM, Protocol::TCP) { |addrinfo| yield addrinfo }
    end

    # Resolves *domain* for the UDP protocol and returns an `Array` of possible
    # `Addrinfo`. See `#resolve` for details.
    #
    # Example:
    # ```
    # require "socket"
    #
    # addrinfos = Socket::Addrinfo.udp("example.org", 53)
    # ```
    def self.udp(domain, service, family = Family::UNSPEC, timeout = nil) : Array(Addrinfo)
      resolve(domain, service, family, Type::DGRAM, Protocol::UDP)
    end

    # Resolves a domain for the UDP protocol with DGRAM type, and yields each
    # possible `Addrinfo`. See `#resolve` for details.
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
      else
        # TODO: (asterite) UNSPEC and UNIX unsupported?
      end
    end

    @ip_address : IPAddress?

    # Returns an `IPAddress` matching this addrinfo.
    def ip_address
      @ip_address ||= IPAddress.from(to_unsafe, size)
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
