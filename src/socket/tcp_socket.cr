require "./ip_socket"

class TCPSocket < IPSocket
  def initialize(host, port)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP) do |ai|
      sock = create_socket(ai.family, ai.socktype, ai.protocol)

      if LibC.connect(sock, ai.addr, ai.addrlen) != 0
        LibC.close(sock)
        next false if ai.next
        raise Errno.new("Error connecting to '#{host}:#{port}'")
      end

      super sock

      true
    end
  end

  def initialize(fd : Int32)
    super fd
  end

  def self.open(host, port)
    sock = new(host, port)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def tcp_nodelay?
    v = 0
    ret = getsockopt LibC::TCP_NODELAY, v, level: LibC::IPPROTO_TCP
    ret != 0
  end

  def tcp_nodelay= val : Bool
    v = val ? 1 : 0
    setsockopt LibC::TCP_NODELAY, v, level: LibC::IPPROTO_TCP
    val
  end
end
