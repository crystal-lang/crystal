module Crystal::System::Addrinfo
  # alias Handle

  # protected def initialize(addrinfo : Handle)

  # def system_ip_address : ::Socket::IPAddress

  # only used by `#system_ip_address`?
  # def to_unsafe

  # def self.getaddrinfo(domain, service, family, type, protocol, timeout) : Handle

  # def self.next_addrinfo(addrinfo : Handle) : Handle

  # def self.free_addrinfo(addrinfo : Handle)
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
