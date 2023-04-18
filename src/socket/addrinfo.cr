require "uri/punycode"
require "./address"

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
    def self.resolve(domain, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil, &)
      getaddrinfo(domain, service, family, type, protocol, timeout) do |addrinfo|
        loop do
          value = yield addrinfo.not_nil!

          if value.is_a?(Exception)
            unless addrinfo = addrinfo.try(&.next?)
              if value.is_a?(Socket::ConnectError)
                raise Socket::ConnectError.from_os_error("Error connecting to '#{domain}:#{service}'", value.os_error)
              else
                {% if flag?(:win32) && compare_versions(Crystal::LLVM_VERSION, "13.0.0") < 0 %}
                  # FIXME: Workaround for https://github.com/crystal-lang/crystal/issues/11047
                  array = StaticArray(UInt8, 0).new(0)
                {% end %}

                raise value
              end
            end
          else
            return value
          end
        end
      end
    end

    class Error < Socket::Error
      @[Deprecated("Use `#os_error` instead")]
      def error_code : Int32
        os_error.not_nil!.value.to_i32!
      end

      @[Deprecated("Use `.from_os_error` instead")]
      def self.new(error_code : Int32, message, domain)
        from_os_error(message, Errno.new(error_code), domain: domain, type: nil, service: nil, protocol: nil)
      end

      @[Deprecated("Use `.from_os_error` instead")]
      def self.new(error_code : Int32, domain)
        new error_code, nil, domain: domain
      end

      protected def self.new_from_os_error(message : String?, os_error, *, domain, type, service, protocol, **opts)
        new(message, **opts)
      end

      protected def self.new_from_os_error(message : String?, os_error, *, domain, **opts)
        new(message, **opts)
      end

      def self.build_message(message, *, domain, **opts)
        "Hostname lookup for #{domain} failed"
      end

      def self.os_error_message(os_error : Errno, *, type, service, protocol, **opts)
        case os_error.value
        when LibC::EAI_NONAME
          "No address found"
        when LibC::EAI_SOCKTYPE
          "The requested socket type #{type} protocol #{protocol} is not supported"
        when LibC::EAI_SERVICE
          "The requested service #{service} is not available for the requested socket type #{type}"
        else
          {% unless flag?(:win32) %}
            # There's no need for a special win32 branch because the os_error on Windows
            # is of type WinError, which wouldn't match this overload anyways.

            String.new(LibC.gai_strerror(os_error.value))
          {% end %}
        end
      end
    end

    private def self.getaddrinfo(domain, service, family, type, protocol, timeout, &)
      {% if flag?(:wasm32) %}
        raise NotImplementedError.new "Socket::Addrinfo.getaddrinfo"
      {% else %}
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
          if service.in?(0, nil) && (hints.ai_flags & LibC::AI_NUMERICSERV)
            hints.ai_flags |= LibC::AI_NUMERICSERV
            service = "00"
          end
        {% end %}
        {% if flag?(:win32) %}
          if service.is_a?(Int) && service < 0
            raise Error.from_os_error(nil, WinError::WSATYPE_NOT_FOUND, domain: domain, type: type, protocol: protocol, service: service)
          end
        {% end %}

        ret = LibC.getaddrinfo(domain, service.to_s, pointerof(hints), out ptr)
        unless ret.zero?
          {% if flag?(:unix) %}
            # EAI_SYSTEM is not defined on win32
            if ret == LibC::EAI_SYSTEM
              raise Error.from_os_error nil, Errno.value, domain: domain
            end
          {% end %}

          error = {% if flag?(:win32) %}
                    WinError.new(ret.to_u32!)
                  {% else %}
                    Errno.new(ret)
                  {% end %}
          raise Error.from_os_error(nil, error, domain: domain, type: type, protocol: protocol, service: service)
        end

        begin
          yield new(ptr)
        ensure
          LibC.freeaddrinfo(ptr)
        end
      {% end %}
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
    def self.tcp(domain, service, family = Family::UNSPEC, timeout = nil, &)
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
    def self.udp(domain, service, family = Family::UNSPEC, timeout = nil, &)
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
    def ip_address : Socket::IPAddress
      @ip_address ||= IPAddress.from(to_unsafe, size)
    end

    def inspect(io : IO)
      io << "Socket::Addrinfo("
      io << ip_address << ", "
      io << family << ", "
      io << type << ", "
      io << protocol
      io << ")"
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
