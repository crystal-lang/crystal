require "./ip_socket"

class TCPSocket < IPSocket
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil)
    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP, timeout: dns_timeout) do |addrinfo|
      super(create_socket(addrinfo.ai_family, addrinfo.ai_socktype, addrinfo.ai_protocol))

      if err = nonblocking_connect host, port, addrinfo, timeout: connect_timeout
        close
        next false if addrinfo.ai_next
        raise err
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

  # If set, disable the Nagle algorithm.
  def tcp_nodelay?
    getsockopt_bool LibC::TCP_NODELAY, level: LibC::IPPROTO_TCP
  end

  def tcp_nodelay=(val : Bool)
    setsockopt_bool LibC::TCP_NODELAY, val, level: LibC::IPPROTO_TCP
  end

  # The amount of time in seconds the connection must be idle before sending keepalive probes.
  def tcp_keepalive_idle
    optname = ifdef darwin
      LibC::TCP_KEEPALIVE
    else
      LibC::TCP_KEEPIDLE
    end
    getsockopt optname, 0, level: LibC::IPPROTO_TCP
  end

  def tcp_keepalive_idle=(val : Int)
    optname = ifdef darwin
      LibC::TCP_KEEPALIVE
    else
      LibC::TCP_KEEPIDLE
    end
    setsockopt optname, val, level: LibC::IPPROTO_TCP
    val
  end

  # The amount of time in seconds between keepalive probes.
  def tcp_keepalive_interval
    getsockopt LibC::TCP_KEEPINTVL, 0, level: LibC::IPPROTO_TCP
  end

  def tcp_keepalive_interval=(val : Int)
    setsockopt LibC::TCP_KEEPINTVL, val, level: LibC::IPPROTO_TCP
    val
  end

  # The number of probes sent, without response before dropping the connection.
  def tcp_keepalive_count
    getsockopt LibC::TCP_KEEPCNT, 0, level: LibC::IPPROTO_TCP
  end

  def tcp_keepalive_count=(val : Int)
    setsockopt LibC::TCP_KEEPCNT, val, level: LibC::IPPROTO_TCP
    val
  end
end
