module Crystal::System::Addrinfo
  alias Handle = LibC::Addrinfo*

  @addr : LibC::SockaddrIn6

  protected def initialize(addrinfo : Handle)
    @family = ::Socket::Family.from_value(addrinfo.value.ai_family)
    @type = ::Socket::Type.from_value(addrinfo.value.ai_socktype)
    @protocol = ::Socket::Protocol.from_value(addrinfo.value.ai_protocol)
    @size = addrinfo.value.ai_addrlen.to_i

    @addr = uninitialized LibC::SockaddrIn6

    case @family
    when ::Socket::Family::INET6
      addrinfo.value.ai_addr.as(LibC::SockaddrIn6*).copy_to(pointerof(@addr).as(LibC::SockaddrIn6*), 1)
    when ::Socket::Family::INET
      addrinfo.value.ai_addr.as(LibC::SockaddrIn*).copy_to(pointerof(@addr).as(LibC::SockaddrIn*), 1)
    else
      # TODO: (asterite) UNSPEC and UNIX unsupported?
    end
  end

  def system_ip_address : ::Socket::IPAddress
    ::Socket::IPAddress.from(to_unsafe, size)
  end

  def to_unsafe
    pointerof(@addr).as(LibC::Sockaddr*)
  end

  def self.getaddrinfo(domain, service, family, type, protocol, timeout) : Handle
    hints = LibC::Addrinfo.new
    hints.ai_family = (family || ::Socket::Family::UNSPEC).to_i32
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

    ret = LibC.getaddrinfo(domain, service.to_s, pointerof(hints), out ptr)
    unless ret.zero?
      if ret == LibC::EAI_SYSTEM
        raise ::Socket::Addrinfo::Error.from_os_error nil, Errno.value, domain: domain
      end

      error = Errno.new(ret)
      raise ::Socket::Addrinfo::Error.from_os_error(nil, error, domain: domain, type: type, protocol: protocol, service: service)
    end
    ptr
  end

  def self.next_addrinfo(addrinfo : Handle) : Handle
    addrinfo.value.ai_next
  end

  def self.free_addrinfo(addrinfo : Handle)
    LibC.freeaddrinfo(addrinfo)
  end
end
