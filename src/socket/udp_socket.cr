require "./ip_socket"

class UDPSocket < IPSocket
  def initialize(family = C::AF_INET)
    super C.socket(family, C::SOCK_DGRAM, C::IPPROTO_UDP).tap do |sock|
      raise Errno.new("Error opening socket") if sock <= 0
    end
  end

  def bind(host, port)
    getaddrinfo(host, port, nil, C::SOCK_DGRAM, C::IPPROTO_UDP) do |ai|
      optval = 1
      C.setsockopt(fd, C::SOL_SOCKET, C::SO_REUSEADDR, pointerof(optval) as Void*, sizeof(Int32))

      if C.bind(fd, ai.addr, ai.addrlen) != 0
        raise Errno.new("Error binding TCP server at #{host}#{port}")
      end
    end
  end

  def connect(host, port)
    getaddrinfo(host, port, nil, C::SOCK_DGRAM, C::IPPROTO_UDP) do |ai|
      if C.connect(fd, ai.addr, ai.addrlen) != 0
        raise Errno.new("Error binding TCP server at #{host}#{port}")
      end
    end
  end
end
