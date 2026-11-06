require "./ip_socket"
require "./happy_eyeballs"

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
  {% begin %}
    # Creates a new `TCPSocket`, waiting to be connected.
    def self.new(family : Family = Family::INET, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated("Use Socket.set_blocking instead.")] {% end %} blocking = nil)
      super(af: family, type: Type::STREAM, protocol: Protocol::TCP, blocking: blocking)
    end
  {% end %}

  {% begin %}
    # Creates a new TCP connection to a remote TCP server.
    #
    # You may limit the DNS resolution time with `dns_timeout` and limit the
    # connection time to the remote server with `connect_timeout`. Both values
    # should be `Time::Span`. The `connect_timeout` applies to each connection
    # attempt individually.
    #
    # When *host* resolves to multiple addresses, the connection is established
    # following the Happy Eyeballs algorithm ([RFC 8305](https://www.rfc-editor.org/rfc/rfc8305)):
    # the addresses are interleaved by address family (IPv6 and IPv4) while
    # preserving the order of preference returned by the resolver, then a
    # connection attempt is started for each address in turn. A new attempt
    # starts as soon as the previous one fails, or after 250 milliseconds
    # without the previous attempts having succeeded, in which case several
    # attempts race in parallel. The first established connection is used and
    # all the other attempts are canceled.
    #
    # NOTE: The DNS resolution itself doesn't follow RFC 8305 (the AAAA and A
    # queries aren't made in parallel); the addresses are resolved before any
    # connection attempt starts.
    def initialize(host : String, port, dns_timeout : Time::Span? = nil, connect_timeout = nil, {% if compare_versions(Crystal::VERSION, "1.5.0") >= 0 %} @[Deprecated("Use Socket.set_blocking instead.")] {% end %} blocking = nil)
      addrinfos = Addrinfo.tcp(host, port, timeout: dns_timeout)
      initialize(addrinfos, host, port, connect_timeout: connect_timeout, blocking: blocking)
    end
  {% end %}

  # :ditto:
  @[Deprecated("Use `.new(String, _, Time::Span?)` instead.")]
  def initialize(host : String, port, dns_timeout : Number, connect_timeout = nil, blocking = nil)
    initialize(host, port, dns_timeout.seconds, connect_timeout, blocking: blocking)
  end

  # :nodoc:
  #
  # Connects to one of *addrinfos* following the Happy Eyeballs algorithm (see
  # `.new(String, _, Time::Span?)`). The *host* and *port* are only used to
  # build the error message.
  def initialize(addrinfos : Indexable(Addrinfo), host, port, *, connect_timeout = nil, connection_attempt_delay : Time::Span = HappyEyeballs::CONNECTION_ATTEMPT_DELAY, blocking = nil)
    if addrinfos.size == 1
      # fast path: no need for concurrent connection attempts
      addrinfo = addrinfos.first
      super(af: addrinfo.family, type: addrinfo.type, protocol: addrinfo.protocol, blocking: blocking)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        raise TCPSocket.connect_error(error, host, port)
      end
    else
      result = HappyEyeballs.connect(addrinfos, connect_timeout, connection_attempt_delay) do |addrinfo|
        ConnectionAttempt.new(addrinfo, blocking)
      end
      raise TCPSocket.connect_error(result, host, port) unless result.is_a?(ConnectionAttempt)

      # adopt the connected socket
      addrinfo = result.addrinfo
      super(handle: result.socket.release_handle, family: addrinfo.family, type: addrinfo.type, protocol: addrinfo.protocol, blocking: result.blocking)
      self.sync = true
    end
  end

  # :nodoc:
  def self.connect_error(error : Exception?, host, port) : Exception
    case error
    when Socket::ConnectError
      Socket::ConnectError.from_os_error("Error connecting to '#{host}:#{port}'", error.os_error)
    when Exception
      error
    else
      Socket::ConnectError.new("Error connecting to '#{host}:#{port}': No address found")
    end
  end

  # A bare socket to race in `HappyEyeballs.connect`, with the information
  # needed to adopt it into a `TCPSocket` once connected.
  private struct ConnectionAttempt
    getter socket : Socket
    getter addrinfo : Addrinfo
    getter blocking : Bool

    def initialize(@addrinfo : Addrinfo, blocking)
      handle, @blocking = Crystal::EventLoop.current.socket(addrinfo.family, addrinfo.type, addrinfo.protocol, blocking)
      @socket = Socket.new(handle: handle, family: addrinfo.family, type: addrinfo.type, protocol: addrinfo.protocol, blocking: @blocking)
    end

    def connect(addrinfo, timeout, &)
      @socket.connect(addrinfo, timeout) { |error| yield error }
    end

    def close : Nil
      @socket.close
    end
  end

  protected def initialize(family : Family, type : Type, protocol : Protocol = Protocol::IP)
    super family, type, protocol
  end

  # Internal constructor for `TCPServer#accept?`.
  # The *blocking* arg is purely informational.
  protected def initialize(*, handle, family, type, protocol, blocking)
    super(handle: handle, family: family, type: type, protocol: protocol, blocking: blocking)
  end

  {% begin %}
    # Creates an UNIXSocket from an existing system file descriptor or socket
    # handle.
    #
    # This adopts *fd* into the IO system that will reconfigure it as per the
    # event loop runtime requirements.
    #
    # NOTE: On Windows, the handle must have been created with
    # `WSA_FLAG_OVERLAPPED`.
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
