class Socket
  struct Addrinfo
    class Evented < Resolver
      def getaddrinfo(domain, service, family, type, protocol = Protocol::IP, timeout = nil, &block) : Nil
        hints = LibEvent2::EvutilAddrinfo.new
        hints.ai_family = (family || Family::UNSPEC).to_i32
        hints.ai_socktype = type
        hints.ai_protocol = protocol
        hints.ai_flags = 0

        if service.is_a?(Int)
          hints.ai_flags |= LibC::AI_NUMERICSERV
        end

        dns_base.getaddrinfo(domain, service.to_s, pointerof(hints)) do |addrinfo|
          yield Addrinfo.new(addrinfo)
        end
      end

      private def dns_base
        @dns_base ||= Scheduler.new_dns_base
      end
    end
  end
end
