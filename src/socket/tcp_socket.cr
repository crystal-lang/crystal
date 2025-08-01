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
  {% begin %}
  def self.new(family : Family = Family::INET, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated("Use Socket.set_blocking instead.")] {% end %} blocking = nil)
    super(af: family, type: Type::STREAM, protocol: Protocol::TCP, blocking: blocking)
  end
  {% end %}

  # Creates a new TCP connection to a remote TCP server.
  #
  # You may limit the DNS resolution time with `dns_timeout` and limit the
  # connection time to the remote server with `connect_timeout`. Both values
  # must be in seconds (integers or floats).
  {% begin %}
  def initialize(host : String, port, dns_timeout = nil, connect_timeout = nil, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated("Use Socket.set_blocking instead.")] {% end %} blocking = nil)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(af: addrinfo.family, type: addrinfo.type, protocol: addrinfo.protocol, blocking: blocking)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        error
      end
    end
  end
  {% end %}

  protected def initialize(family : Family, type : Type, protocol : Protocol = Protocol::IP)
    super family, type, protocol
  end

  # Internal constructor for `TCPServer#accept?`.
  # The *blocking* arg is purely informational.
  protected def initialize(*, handle, family, type, protocol, blocking)
    super(handle: handle, family: family, type: type, protocol: protocol, blocking: blocking)
  end

  # Creates an UNIXSocket from an existing system file descriptor or socket
  # handle.
  #
  # This adopts *fd* into the IO system that will reconfigure it as per the
  # event loop runtime requirements.
  #
  # NOTE: On Windows, the handle must have been created with
  # `WSA_FLAG_OVERLAPPED`.
  {% begin %}
  def initialize(*, fd : Handle, family : Family = Family::INET, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated("Use Socket.set_blocking instead.")] {% end %} blocking = nil)
    super fd, family, Type::STREAM, Protocol::TCP, blocking
  end
  {% end %}

  # Opens a TCP socket to a remote TCP server, yields it to the block, then
  # eventually closes the socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host : String, port, &)
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
