{% if flag?(:win32) %}
  require "c/ws2tcpip"
  require "c/afunix"
{% else %}
  require "c/arpa/inet"
  require "c/sys/un"
  require "c/netinet/in"
{% end %}

class Socket
  {% if flag?(:win32) %}
    begin
      # Initialize Windows Socket API and expect version 2.2
      wsa_version = 0x202
      err = LibC.WSAStartup(wsa_version, out wsadata)
      unless err.zero?
        raise IO::Error.from_os_error("WSAStartup", WinError.new(err.to_u32))
      end

      if wsadata.wVersion != wsa_version
        raise IO::Error.new("Unsuitable version of the Windows Socket API: 0x#{wsadata.wVersion.to_s(16)}")
      end
    end
  {% end %}

  enum Protocol
    IP = LibC::IPPROTO_IP
    {% if flag?(:win32) %}
      TCP  = LibC::IPPROTO::IPPROTO_TCP
      UDP  = LibC::IPPROTO::IPPROTO_UDP
      RAW  = LibC::IPPROTO::IPPROTO_RAW
      ICMP = LibC::IPPROTO::IPPROTO_ICMP
    {% else %}
      TCP  = LibC::IPPROTO_TCP
      UDP  = LibC::IPPROTO_UDP
      RAW  = LibC::IPPROTO_RAW
      ICMP = LibC::IPPROTO_ICMP
    {% end %}
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

  enum Type
    STREAM    = LibC::SOCK_STREAM
    DGRAM     = LibC::SOCK_DGRAM
    RAW       = LibC::SOCK_RAW
    SEQPACKET = LibC::SOCK_SEQPACKET
  end

  class Error < IO::Error
    private def self.new_from_os_error(message, os_error, **opts)
      case os_error
      when Errno::ECONNREFUSED
        Socket::ConnectError.new(message, **opts)
      when Errno::EADDRINUSE
        Socket::BindError.new(message, **opts)
      else
        super message, os_error, **opts
      end
    end
  end

  class ConnectError < Error
  end

  class BindError < Error
  end
end
