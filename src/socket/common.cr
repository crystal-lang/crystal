require "c/arpa/inet"
require "c/sys/un"
require "c/netinet/in"

class Socket
  enum Protocol
    IP   = LibC::IPPROTO_IP
    TCP  = LibC::IPPROTO_TCP
    UDP  = LibC::IPPROTO_UDP
    RAW  = LibC::IPPROTO_RAW
    ICMP = LibC::IPPROTO_ICMP
  end

  enum Family : LibC::SaFamilyT
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
