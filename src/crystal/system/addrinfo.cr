module Crystal::System::Addrinfo
  # alias Handle

  # protected def initialize(addrinfo : Handle)

  # def system_ip_address : ::Socket::IPAddress

  # only used by `#system_ip_address`?
  # def to_unsafe

  # def self.getaddrinfo(domain, service, family, type, protocol, timeout) : Handle

  # def self.next_addrinfo(addrinfo : Handle) : Handle

  # def self.free_addrinfo(addrinfo : Handle)

  def self.getaddrinfo(domain, service, family, type, protocol, timeout, & : ::Socket::Addrinfo ->)
    addrinfo = root = getaddrinfo(domain, service, family, type, protocol, timeout)

    begin
      while addrinfo
        yield ::Socket::Addrinfo.new(addrinfo)
        addrinfo = next_addrinfo(addrinfo)
      end
    ensure
      free_addrinfo(root)
    end
  end
end

{% if flag?(:wasi) %}
  require "./wasi/addrinfo"
{% elsif flag?(:unix) %}
  require "./unix/addrinfo"
{% elsif flag?(:win32) %}
  require "./win32/addrinfo"
{% else %}
  {% raise "No Crystal::System::Addrinfo implementation available" %}
{% end %}
