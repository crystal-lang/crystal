require "./ip_socket"

# A Transmission Control Protocol (TCP/IP) socket.
#
# NOTE: To use `TCPSocket`, you must explicitly import it with `require "socket"`
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
  def self.new(family : Family = Family::INET, blocking = false)
    super(family, Type::STREAM, Protocol::TCP, blocking)
  end

  # Creates a new TCP connection to a remote TCP server.
  #
  # You may limit the DNS resolution time with `dns_timeout` and limit the
  # connection time to the remote server with `connect_timeout`. Both values
  # must be in seconds (integers or floats).
  #
  # Note that `dns_timeout` is currently ignored.
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil, blocking = false)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol, blocking)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        error
      end
    end
  end

  protected def initialize(family : Family, type : Type, protocol : Protocol = Protocol::IP, blocking = false)
    super family, type, protocol, blocking
  end

  protected def initialize(fd : Handle, family : Family, type : Type, protocol : Protocol = Protocol::IP, blocking = false)
    super fd, family, type, protocol, blocking
  end

  # Creates a TCPSocket from an already configured raw file descriptor
  def initialize(*, fd : Handle, family : Family = Family::INET, blocking = false)
    super fd, family, Type::STREAM, Protocol::TCP, blocking
  end

  # Opens a TCP socket to a remote TCP server, yields it to the block, then
  # eventually closes the socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port, &)
    sock = new(host, port)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Returns `true` if the Nagle algorithm is disabled.
  def tcp_nodelay? : Bool
    getsockopt_bool LibC::TCP_NODELAY, level: Protocol::TCP
  end

  # Disables the Nagle algorithm when set to `true`, otherwise enables it.
  def tcp_nodelay=(val : Bool)
    setsockopt_bool LibC::TCP_NODELAY, val, level: Protocol::TCP
  end

  # The amount of time in seconds the connection must be idle before sending keepalive probes.
  def tcp_keepalive_idle
    system_tcp_keepalive_idle
  end

  def tcp_keepalive_idle=(val : Int)
    self.system_tcp_keepalive_idle = val
  end

  # The amount of time in seconds between keepalive probes.
  def tcp_keepalive_interval
    system_tcp_keepalive_interval
  end

  def tcp_keepalive_interval=(val : Int)
    self.system_tcp_keepalive_interval = val
    val
  end

  # The number of probes sent, without response before dropping the connection.
  def tcp_keepalive_count
    system_tcp_keepalive_count
  end

  def tcp_keepalive_count=(val : Int)
    self.system_tcp_keepalive_count = val
  end
end
