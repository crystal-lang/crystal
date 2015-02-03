require "./ip_socket"

class UDPSocket < IPSocket
  def initialize(family = LibC::AF_INET)
    super LibC.socket(family, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP).tap do |sock|
      raise Errno.new("Error opening socket") if sock <= 0
    end
  end

  def bind(host, port)
    getaddrinfo(host, port, nil, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP) do |ai|
      optval = 1
      LibC.setsockopt(fd, LibC::SOL_SOCKET, LibC::SO_REUSEADDR, pointerof(optval) as Void*, sizeof(Int32))

      if LibC.bind(fd, ai.addr, ai.addrlen) != 0
        next false if ai.next
        raise Errno.new("Error binding UDP socket at #{host}:#{port}")
      end

      true
    end
  end

  def connect(host, port)
    getaddrinfo(host, port, nil, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP) do |ai|
      if LibC.connect(fd, ai.addr, ai.addrlen) != 0
        next false if ai.next
        raise Errno.new("Error connecting UDP socket at #{host}:#{port}")
      end

      true
    end
  end
end
