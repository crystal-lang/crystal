require "uri/punycode"
require "./address"
require "crystal/system/addrinfo"

class Socket
  # Domain name resolver.
  #
  # # Query Concurrency Behaviour
  #
  # On most platforms, DNS queries are currently resolved synchronously.
  # Calling a resolve method blocks the entire thread until it returns.
  # This can cause latencies, especially in single-threaded processes.
  #
  # DNS queries resolve asynchronously on the following platforms:
  #
  # * Windows 8 and higher
  #
  # NOTE: Follow the discussion in [Async DNS resolution (#13619)](https://github.com/crystal-lang/crystal/issues/13619)
  # for more details.
  struct Addrinfo
    include Crystal::System::Addrinfo

    getter family : Family
    getter type : Type
    getter protocol : Protocol
    getter size : Int32

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
    # - *timeout* is optional and specifies the maximum time to wait before
    #   `IO::TimeoutError` is raised. Currently this is only supported on
    #   Windows.
    #
    # Example:
    # ```
    # require "socket"
    #
    # addrinfos = Socket::Addrinfo.resolve("example.org", "http", type: Socket::Type::STREAM, protocol: Socket::Protocol::TCP)
    # ```
    def self.resolve(domain : String, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil) : Array(Addrinfo)
      addrinfos = [] of Addrinfo

      getaddrinfo(domain, service, family, type, protocol, timeout) do |addrinfo|
        addrinfos << addrinfo
      end

      addrinfos
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
    def self.resolve(domain : String, service, family : Family? = nil, type : Type = nil, protocol : Protocol = Protocol::IP, timeout = nil, &)
      exception = nil

      getaddrinfo(domain, service, family, type, protocol, timeout) do |addrinfo|
        value = yield addrinfo

        if value.is_a?(Exception)
          exception = value
        else
          return value
        end
      end

      case exception
      when Socket::ConnectError
        raise Socket::ConnectError.from_os_error("Error connecting to '#{domain}:#{service}'", exception.os_error)
      when Exception
        {% if flag?(:win32) && compare_versions(Crystal::LLVM_VERSION, "13.0.0") < 0 %}
          # FIXME: Workaround for https://github.com/crystal-lang/crystal/issues/11047
          array = StaticArray(UInt8, 0).new(0)
        {% end %}

        raise exception
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

      def self.os_error_message(os_error : Errno | WinError, *, type, service, protocol, **opts)
        # when `EAI_NONAME` etc. is an integer then only `os_error.value` can
        # match; when `EAI_NONAME` is a `WinError` then `os_error` itself can
        # match
        case os_error.is_a?(Errno) ? os_error.value : os_error
        when LibC::EAI_NONAME
          "No address found"
        when LibC::EAI_SOCKTYPE
          "The requested socket type #{type} protocol #{protocol} is not supported"
        when LibC::EAI_SERVICE
          "The requested service #{service} is not available for the requested socket type #{type}"
        else
          # Win32 also has this method, but `WinError` is already sufficient
          {% if LibC.has_method?(:gai_strerror) %}
            if os_error.is_a?(Errno)
              return String.new(LibC.gai_strerror(os_error))
            end
          {% end %}

          super
        end
      end
    end

    private def self.getaddrinfo(domain, service, family, type, protocol, timeout, &)
      # RFC 3986 says:
      # > When a non-ASCII registered name represents an internationalized domain name
      # > intended for resolution via the DNS, the name must be transformed to the IDNA
      # > encoding [RFC3490] prior to name lookup.
      domain = URI::Punycode.to_ascii domain

      Crystal::System::Addrinfo.getaddrinfo(domain, service, family, type, protocol, timeout) do |addrinfo|
        yield addrinfo
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
    def self.tcp(domain : String, service, family = Family::UNSPEC, timeout = nil) : Array(Addrinfo)
      resolve(domain, service, family, Type::STREAM, Protocol::TCP, timeout)
    end

    # Resolves a domain for the TCP protocol with STREAM type, and yields each
    # possible `Addrinfo`. See `#resolve` for details.
    def self.tcp(domain : String, service, family = Family::UNSPEC, timeout = nil, &)
      resolve(domain, service, family, Type::STREAM, Protocol::TCP, timeout) { |addrinfo| yield addrinfo }
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
    def self.udp(domain : String, service, family = Family::UNSPEC, timeout = nil) : Array(Addrinfo)
      resolve(domain, service, family, Type::DGRAM, Protocol::UDP, timeout)
    end

    # Resolves a domain for the UDP protocol with DGRAM type, and yields each
    # possible `Addrinfo`. See `#resolve` for details.
    def self.udp(domain : String, service, family = Family::UNSPEC, timeout = nil, &)
      resolve(domain, service, family, Type::DGRAM, Protocol::UDP, timeout) { |addrinfo| yield addrinfo }
    end

    # Returns an `IPAddress` matching this addrinfo.
    getter(ip_address : Socket::IPAddress) do
      system_ip_address
    end

    def inspect(io : IO)
      io << "Socket::Addrinfo("
      io << ip_address << ", "
      io << family << ", "
      io << type << ", "
      io << protocol
      io << ")"
    end
  end
end
