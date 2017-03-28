class Socket
  struct Addrinfo
    abstract class Resolver
      abstract def getaddrinfo(domain, service, family, type, protocol, timeout = nil, &block) : Nil
    end

    class_setter resolver : Resolver?

    def self.resolver
      @@resolver ||= Blocking.new
    end
  end
end
