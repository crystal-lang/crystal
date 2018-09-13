class Socket < IO
  class Error < Exception
  end

  enum Type
    STREAM    = LibC::SOCK_STREAM
    DGRAM     = LibC::SOCK_DGRAM
    RAW       = LibC::SOCK_RAW
    SEQPACKET = LibC::SOCK_SEQPACKET
  end

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

  SOMAXCONN = 128
end
