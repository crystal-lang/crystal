require "./ip_socket"

# A Transmission Control Protocol (TCP/IP) socket.
#
# Usage example:
# ```
# require "socket"
#
# client = TCPSocket.new("localhost", 1234)
# client << "message\n"
# response = client.gets
# client.close
# ```
class TCPSocket < IPSocket
  # Creates a new `TCPSocket`, waiting to be connected.
  def self.new(family : Family = Family::INET)
    super(family, Type::STREAM, Protocol::TCP)
  end

  # Creates a new TCP connection to a remote TCP server.
  #
  # You may limit the DNS resolution time with `dns_timeout` and limit the
  # connection time to the remote server with `connect_timeout`. Both values
  # must be in seconds (integers or floats).
  #
  # Note that `dns_timeout` is currently ignored.
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        error
      end
    end
  end

  protected def initialize(family : Family, type : Type, protocol : Protocol)
    super family, type, protocol
  end

  protected def initialize(fd : Int32, family : Family, type : Type, protocol : Protocol)
    super fd, family, type, protocol
  end

  # Opens a TCP socket to a remote TCP server, yields it to the block, then
  # eventually closes the socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port)
    sock = new(host, port)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Returns `true` if the Nable algorithm is disabled.
  def tcp_nodelay?
    getsockopt_bool LibC::TCP_NODELAY, level: Protocol::TCP
  end

  # Disable the Nagle algorithm when set to `true`, otherwise enables it.
  def tcp_nodelay=(val : Bool)
    setsockopt_bool LibC::TCP_NODELAY, val, level: Protocol::TCP
  end

  {% unless flag?(:openbsd) %}
    # The amount of time in seconds the connection must be idle before sending keepalive probes.
    def tcp_keepalive_idle
      optname = {% if flag?(:darwin) %}
        LibC::TCP_KEEPALIVE
      {% else %}
        LibC::TCP_KEEPIDLE
      {% end %}
      getsockopt optname, 0, level: Protocol::TCP
    end

    def tcp_keepalive_idle=(val : Int)
      optname = {% if flag?(:darwin) %}
        LibC::TCP_KEEPALIVE
      {% else %}
        LibC::TCP_KEEPIDLE
      {% end %}
      setsockopt optname, val, level: Protocol::TCP
      val
    end

    # The amount of time in seconds between keepalive probes.
    def tcp_keepalive_interval
      getsockopt LibC::TCP_KEEPINTVL, 0, level: Protocol::TCP
    end

    def tcp_keepalive_interval=(val : Int)
      setsockopt LibC::TCP_KEEPINTVL, val, level: Protocol::TCP
      val
    end

    # The number of probes sent, without response before dropping the connection.
    def tcp_keepalive_count
      getsockopt LibC::TCP_KEEPCNT, 0, level: Protocol::TCP
    end

    def tcp_keepalive_count=(val : Int)
      setsockopt LibC::TCP_KEEPCNT, val, level: Protocol::TCP
      val
    end
  {% end %}
end
