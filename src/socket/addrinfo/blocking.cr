require "./resolver"

class Socket
  struct Addrinfo
    # Calls the system `getaddrinfo` function directly from the current thread.
    # Blocks the event loop until the domain is resolved by the system.
    #
    # The `timeout` parameter is discarded.
    class Blocking < Resolver
      def getaddrinfo(domain, service, family, type, protocol, timeout = nil, &block)
        hints = LibC::Addrinfo.new
        hints.ai_family = (family || Family::UNSPEC).to_i32
        hints.ai_socktype = type
        hints.ai_protocol = protocol
        hints.ai_flags = 0

        if service.is_a?(Int)
          hints.ai_flags |= LibC::AI_NUMERICSERV

          {% if flag?(:darwin) %}
            # avoid a segfault on macOS < 10.12
            if service == 0 || service == nil
              service = "00"
            end
          {% end %}
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
          yield Addrinfo.new(ptr)
        ensure
          LibC.freeaddrinfo(ptr)
        end
      end
    end
  end
end
