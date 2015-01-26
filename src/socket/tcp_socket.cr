require "./ip_socket"

class TCPSocket < IPSocket
  def initialize(host, port)
    getaddrinfo(host, port, nil, C::SOCK_STREAM, C::IPPROTO_TCP) do |ai|
      sock = C.socket(afamily(ai.family), ai.socktype, ai.protocol)
      raise Errno.new("Error opening socket") if sock <= 0

      if C.connect(sock, ai.addr, ai.addrlen) != 0
        raise Errno.new("Error connecting to '#{host}:#{port}'")
      end

      super sock
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
end
