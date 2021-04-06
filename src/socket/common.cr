{% if flag?(:win32) %}
  require "c/ws2tcpip"
  require "c/afunix"
{% else %}
  require "c/arpa/inet"
  require "c/sys/un"
  require "c/netinet/in"
{% end %}

class Socket
  enum Protocol
    IP   = LibC::IPPROTO_IP
    TCP  = LibC::IPPROTO_TCP
    UDP  = LibC::IPPROTO_UDP
    RAW  = LibC::IPPROTO_RAW
    ICMP = LibC::IPPROTO_ICMP
  end

  # :nodoc:
  {% if flag?(:win32) %}
    alias FamilyT = UInt8
  {% else %}
    alias FamilyT = LibC::SaFamilyT
  {% end %}

  enum Family : FamilyT
    UNSPEC = LibC::AF_UNSPEC
    UNIX   = LibC::AF_UNIX
    INET   = LibC::AF_INET
    INET6  = LibC::AF_INET6
  end

  class Error < IO::Error
    private def self.new_from_errno(message, errno, **opts)
      case errno
      when Errno::ECONNREFUSED
        Socket::ConnectError.new(message, **opts)
      when Errno::EADDRINUSE
        Socket::BindError.new(message, **opts)
      else
        super message, errno, **opts
      end
    end
  end

  class ConnectError < Error
  end

  class BindError < Error
  end
end
