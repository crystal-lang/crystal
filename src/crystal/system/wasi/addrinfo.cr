module Crystal::System::Addrinfo
  alias Handle = NoReturn

  protected def initialize(addrinfo : Handle)
    raise NotImplementedError.new("Crystal::System::Addrinfo#initialize")
  end

  def system_ip_address : ::Socket::IPAddress
    raise NotImplementedError.new("Crystal::System::Addrinfo#system_ip_address")
  end

  def to_unsafe
    raise NotImplementedError.new("Crystal::System::Addrinfo#to_unsafe")
  end

  def self.getaddrinfo(domain, service, family, type, protocol, timeout) : Handle
    raise NotImplementedError.new("Crystal::System::Addrinfo.getaddrinfo")
  end

  def self.next_addrinfo(addrinfo : Handle) : Handle
    raise NotImplementedError.new("Crystal::System::Addrinfo.next_addrinfo")
  end

  def self.free_addrinfo(addrinfo : Handle)
    raise NotImplementedError.new("Crystal::System::Addrinfo.free_addrinfo")
  end
end
