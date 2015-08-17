require "./ip_socket"

class TCPSocket < IPSocket
  def initialize(host, port, dns_timeout = nil)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP, timeout: dns_timeout) do |ai|
      super create_socket(ai.family, ai.socktype, ai.protocol)

      unless nonblocking_connect ai
        errno = LibC.errno
        close
        next false if ai.next
        LibC.errno = errno
        raise Errno.new("Error connecting to '#{host}:#{port}'")
      end

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
end
