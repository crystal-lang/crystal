require "c/sys/socket"
require "./addrinfo"

# This class represents a raw network socket.
#
# It is an object oriented wrapper for BSD-style socket API provided by POSIX operating
# systems and Windows.
#
# This class is not intended to be used for typical network applications. There
# are more specific implementations `TCPSocket`, `UDPSocket`, `UNIXSocket`, `TCPServer`, and `UNIXServer`.
# It allows finer-grained control over socket parameters than the protocol-specific classes
# and only needs to be employed for less common tasks that need low-level access to the OS sockets.
class Socket::Raw < IO
  include IO::Buffered
  include IO::Syscall

  # The raw file-descriptor. It is defined to be an `Int32`, but its actual size is
  # platform-specific.
  getter fd : Int32

  @read_event : Crystal::Event?
  @write_event : Crystal::Event?

  @closed : Bool

  getter family : Family
  getter type : Type
  getter protocol : Protocol

  # Creates a new raw socket for TCP protocol.
  #
  # Consider using `TCPSocket` or `TCPServer` instead.
  def self.tcp(family : Family, *,
               blocking : Bool = false)
    new(family, Type::STREAM, Protocol::TCP, blocking: blocking)
  end

  # Creates a new raw socket for UDP protocol.
  #
  # Consider using `UDPSocket` instead.
  def self.udp(family : Family, *,
               blocking : Bool = false)
    new(family, Type::DGRAM, Protocol::UDP, blocking: blocking)
  end

  # Creates a new raw socket for UNIX sockets.
  #
  # Consider using `UNIXSocket` or `UNIXServer` instead.
  def self.unix(type : Type = Type::STREAM, *,
                blocking : Bool = false)
    new(Family::UNIX, type, blocking: blocking)
  end

  # Creates a new raw socket.
  def initialize(@family : Family, @type : Type, @protocol : Protocol = Protocol::IP, *,
                 blocking : Bool = false)
    @closed = false
    fd = LibC.socket(family, type, protocol)
    raise Errno.new("failed to create socket:") if fd == -1
    init_close_on_exec(fd)
    @fd = fd

    self.sync = true
    unless blocking
      self.blocking = false
    end
  end

  protected def initialize(@fd : Int32, @family, @type, @protocol = Protocol::IP, *,
                           blocking : Bool = false)
    @closed = false
    init_close_on_exec(@fd)

    self.sync = true
    unless blocking
      self.blocking = false
    end
  end

  # Force opened sockets to be closed on `exec(2)`. Only for platforms that don't
  # support `SOCK_CLOEXEC` (e.g., Darwin).
  protected def init_close_on_exec(fd : Int32)
    {% unless LibC.has_constant?(:SOCK_CLOEXEC) %}
      LibC.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
    {% end %}
  end

  # Connects the socket to a IP socket address specified by *host* and *port*.
  #
  # ```
  # sock = Socket::Raw.tcp(Socket::Family::INET)
  # sock.connect "crystal-lang.org", 80
  # ```
  #
  # This method involves address resolution, provided by `Addrinfo.resolve`.
  #
  # Raises `Socket::Error` if the address cannot be resolved or connection fails.
  def connect(host : String, port : Int, *,
              dns_timeout = nil, connect_timeout = nil)
    Addrinfo.resolve(host, port, @family, @type, @protocol, dns_timeout) do |addrinfo|
      connect(addrinfo, connect_timeout: connect_timeout) { |error| error }
    end
  end

  # Connects the socket to a socket address specified by *address*.
  #
  # ```
  # sock = Socket::Raw.unix
  # sock.connect Socket::UNIXAddress.new("/tmp/service.sock")
  # ```
  #
  # Raises `Socket::Error` if the connection fails.
  def connect(address : Address | Addrinfo, *,
              connect_timeout = nil) : Nil
    connect(address, connect_timeout: connect_timeout) { |error| raise error }
  end

  # Connects the socket to a socket address specified by *address*.
  #
  # In case the connection failed, it yields an `IO::Timeout` or `Errno` error.
  def connect(address : Address | Addrinfo, *,
              connect_timeout = nil, &block : IO::Timeout | Errno ->)
    loop do
      if LibC.connect(fd, address, address.size) == 0
        return
      end

      case Errno.value
      when Errno::EISCONN
        return
      when Errno::EINPROGRESS, Errno::EALREADY
        connect_timeout = connect_timeout.seconds unless connect_timeout.is_a? Time::Span | Nil

        wait_writable(timeout: connect_timeout) do |error|
          return yield IO::Timeout.new("connect timed out")
        end
      else
        return yield Errno.new("connect")
      end
    end
  end

  # Binds the socket to a local IP socket address specified by *host* and *port*.
  #
  # ```
  # sock = Socket::Raw.tcp(Socket::Family::INET)
  # sock.bind "localhost", 1234
  # ```
  #
  # This method involves address resolution, provided by `Addrinfo.resolve`.
  #
  # Raises `Socket::Error` if the address cannot be resolved or binding fails.
  def bind(host : String, port : Int)
    Addrinfo.resolve(host, port, @family, @type, @protocol) do |addrinfo|
      bind(addrinfo) { |errno| errno }
    end
  end

  # Binds the socket on *port* to all local interfaces.
  #
  # ```
  # sock = Socket::Raw.tcp(Socket::Family::INET6)
  # sock.bind 1234
  # ```
  #
  # Raises `Socket::Error` if the address cannot be resolved or binding fails.
  def bind(port : Int)
    address = IPAddress.new(IPAddress::ANY, port)
    bind(address) { |errno| errno }
  end

  # Binds the socket to a local address.
  #
  # ```
  # sock = Socket::Raw.udp(Socket::Family::INET)
  # sock.bind Socket::IPAddress.new("192.168.1.25", 80)
  # ```
  #
  # Raises `Errno` if the binding fails.
  def bind(addr : Address | Addrinfo)
    bind(addr) { |errno| raise errno }
  end

  # Tries to bind the socket to a local address.
  #
  # Yields an `Errno` error if the binding fails.
  def bind(addr : Address | Addrinfo)
    unless LibC.bind(fd, addr, addr.size) == 0
      yield Errno.new("bind")
    end
  end

  # Tells the previously bound socket to listen for incoming connections.
  #
  # Raises `Errno` if listening fails.
  def listen(*, backlog : Int32 = SOMAXCONN)
    listen(backlog: backlog) { |errno| raise errno }
  end

  # Tries to listen for connections on the previously bound socket.
  #
  # Yields an `Errno` error if listening fails.
  def listen(*, backlog : Int32 = SOMAXCONN)
    unless LibC.listen(fd, backlog) == 0
      yield Errno.new("listen")
    end
  end

  # Accepts an incoming connection.
  #
  # Returns the client socket. Raises an `IO::Error` (closed stream) exception
  # if the server is closed after invoking this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  # socket = server.accept
  # socket.puts Time.now
  # socket.close
  # ```
  def accept
    accept? || raise IO::Error.new("Closed stream")
  end

  # Accepts an incoming connection.
  #
  # Returns the client `Socket` or `nil` if the server is closed after invoking
  # this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2202)
  # if socket = server.accept?
  #   socket.puts Time.now
  #   socket.close
  # end
  # ```
  def accept?
    if client_fd = accept_impl
      sock = Socket::Raw.new(client_fd, family, type, protocol, blocking: blocking)
      sock.sync = sync?
      sock
    end
  end

  protected def accept_impl
    loop do
      client_fd = LibC.accept(fd, nil, nil)
      if client_fd == -1
        if closed?
          return
        elsif Errno.value == Errno::EAGAIN
          wait_readable
        else
          raise Errno.new("accept")
        end
      else
        return client_fd
      end
    end
  end

  # Sends a message to a previously connected remote address.
  #
  # ```
  # sock = Socket::Raw.udp(Socket::Family::INET)
  # sock.connect("example.com", 2000)
  # sock.send("text message")
  #
  # sock = Socket::Raw.unix(Socket::Type::DGRAM)
  # sock.connect Socket::UNIXAddress.new("/tmp/service.sock")
  # sock.send(Bytes[0])
  # ```
  def send(message)
    slice = message.to_slice
    bytes_sent = LibC.send(fd, slice.to_unsafe.as(Void*), slice.size, 0)
    raise Errno.new("Error sending datagram") if bytes_sent == -1
    bytes_sent
  ensure
    # see IO::FileDescriptor#unbuffered_write
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  # Sends a message to the specified remote address.
  #
  # ```
  # server = Socket::IPAddress.new("10.0.3.1", 2022)
  # sock = Socket::Raw.udp(Socket::Family::INET)
  # sock.connect("example.com", 2000)
  # sock.send("text query", to: server)
  # ```
  def send(message, *, to addr : Address)
    slice = message.to_slice
    bytes_sent = LibC.sendto(fd, slice.to_unsafe.as(Void*), slice.size, 0, addr, addr.size)
    raise Errno.new("Error sending datagram to #{addr}") if bytes_sent == -1
    bytes_sent
  end

  # Receives a text message from the previously bound address.
  #
  # ```
  # server = Socket::Raw.udp(Socket::Family::INET)
  # server.bind("localhost", 1234)
  #
  # message, client_addr = server.receive
  # ```
  def receive(*, max_message_size = 512) : {String, Address}
    address = nil
    message = String.new(max_message_size) do |buffer|
      bytes_read, sockaddr, addrlen = recvfrom(Slice.new(buffer, max_message_size))
      address = Address.from(sockaddr, addrlen)
      {bytes_read, 0}
    end
    {message, address.not_nil!}
  end

  # Receives a binary message from the previously bound address.
  #
  # ```
  # server = Socket::Raw.udp(Socket::Family::INET)
  # server.bind("localhost", 1234)
  #
  # message = Bytes.new(32)
  # bytes_read, client_addr = server.receive(message)
  # ```
  def receive(message : Bytes) : {Int32, Address}
    bytes_read, sockaddr, addrlen = recvfrom(message)
    {bytes_read, Address.from(sockaddr, addrlen)}
  end

  # :nodoc:
  def recvfrom(message)
    sockaddr = Pointer(LibC::SockaddrStorage).malloc.as(LibC::Sockaddr*)
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    loop do
      bytes_read = LibC.recvfrom(fd, message.to_unsafe.as(Void*), message.size, 0, sockaddr, pointerof(addrlen))
      if bytes_read == -1
        if Errno.value == Errno::EAGAIN
          wait_readable
        else
          raise Errno.new("Error receiving datagram")
        end
      else
        return {bytes_read.to_i, sockaddr, addrlen}
      end
    end
  ensure
    # see IO::FileDescriptor#unbuffered_read
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end

  # Calls `shutdown(2)` with `SHUT_RD`
  def close_read
    shutdown LibC::SHUT_RD
  end

  # Calls `shutdown(2)` with `SHUT_WR`
  def close_write
    shutdown LibC::SHUT_WR
  end

  private def shutdown(how)
    if LibC.shutdown(@fd, how) != 0
      raise Errno.new("shutdown #{how}")
    end
  end

  # Returns the `Address` for the local end of the socket.
  def local_address : Address
    local_address(Address)
  end

  # Returns the `Address` for the remote end of the socket.
  def remote_address : Address
    remote_address(Address)
  end

  # :nodoc:
  def local_address(address_type : Address.class)
    sockaddr_max = uninitialized LibC::SockaddrUn
    sockaddr = pointerof(sockaddr_max).as(LibC::Sockaddr*)
    orig_addrlen = addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrUn))

    if LibC.getsockname(@fd, sockaddr, pointerof(addrlen)) != 0
      raise Errno.new("getsockname")
    end

    address_type.from sockaddr, addrlen
  end

  # :nodoc:
  def remote_address(address_type : Address.class)
    sockaddr6 = uninitialized LibC::SockaddrUn
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrUn))

    if LibC.getpeername(@fd, sockaddr, pointerof(addrlen)) != 0
      raise Errno.new("getpeername")
    end

    address_type.from sockaddr, addrlen
  end

  def inspect(io)
    io << "#<#{self.class}:fd #{@fd}>"
  end

  def send_buffer_size
    getsockopt LibC::SO_SNDBUF, 0
  end

  def send_buffer_size=(val : Int32)
    setsockopt LibC::SO_SNDBUF, val
    val
  end

  def recv_buffer_size
    getsockopt LibC::SO_RCVBUF, 0
  end

  def recv_buffer_size=(val : Int32)
    setsockopt LibC::SO_RCVBUF, val
    val
  end

  def reuse_address?
    getsockopt_bool LibC::SO_REUSEADDR
  end

  def reuse_address=(val : Bool)
    setsockopt_bool LibC::SO_REUSEADDR, val
  end

  def reuse_port?
    ret = getsockopt(LibC::SO_REUSEPORT, 0) do |errno|
      # If SO_REUSEPORT is not supported, the return value should be `false`
      if errno.errno == Errno::ENOPROTOOPT
        return false
      else
        raise errno
      end
    end
    ret != 0
  end

  def reuse_port=(val : Bool)
    setsockopt_bool LibC::SO_REUSEPORT, val
  end

  def broadcast?
    getsockopt_bool LibC::SO_BROADCAST
  end

  def broadcast=(val : Bool)
    setsockopt_bool LibC::SO_BROADCAST, val
  end

  def keepalive?
    getsockopt_bool LibC::SO_KEEPALIVE
  end

  def keepalive=(val : Bool)
    setsockopt_bool LibC::SO_KEEPALIVE, val
  end

  def linger
    v = LibC::Linger.new
    ret = getsockopt LibC::SO_LINGER, v
    ret.l_onoff == 0 ? nil : ret.l_linger
  end

  # WARNING: The behavior of `SO_LINGER` is platform specific.
  # Bad things may happen especially with nonblocking sockets.
  # See [Cross-Platform Testing of SO_LINGER by Nybek](https://www.nybek.com/blog/2015/04/29/so_linger-on-non-blocking-sockets/)
  # for more information.
  #
  # * `nil`: disable `SO_LINGER`
  # * `Int`: enable `SO_LINGER` and set timeout to `Int` seconds
  #   * `0`: abort on close (socket buffer is discarded and RST sent to peer). Depends on platform and whether `shutdown()` was called first.
  #   * `>=1`: abort after `Int` seconds on close. Linux and Cygwin may block on close.
  def linger=(val : Int?)
    v = LibC::Linger.new
    case val
    when Int
      v.l_onoff = 1
      v.l_linger = val
    when nil
      v.l_onoff = 0
    end

    setsockopt LibC::SO_LINGER, v
    val
  end

  # Returns the modified *optval*.
  def getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    getsockopt(optname, optval, level) { |errno| raise errno }
  end

  protected def getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, (pointerof(optval).as(Void*)), pointerof(optsize))
    yield Errno.new("getsockopt") if ret == -1
    optval
  end

  # NOTE: *optval* is restricted to `Int32` until sizeof works on variables.
  def setsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.setsockopt(fd, level, optname, (pointerof(optval).as(Void*)), optsize)
    raise Errno.new("setsockopt") if ret == -1
    ret
  end

  def getsockopt_bool(optname, level = LibC::SOL_SOCKET)
    ret = getsockopt optname, 0, level
    ret != 0
  end

  def setsockopt_bool(optname, optval : Bool, level = LibC::SOL_SOCKET)
    v = optval ? 1 : 0
    ret = setsockopt optname, v, level
    optval
  end

  def blocking
    fcntl(LibC::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  def blocking=(value)
    flags = fcntl(LibC::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, flags)
  end

  def close_on_exec?
    flags = fcntl(LibC::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  def close_on_exec=(arg : Bool)
    fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
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
    # Returns the amount of time (in seconds) the connection must be idle before sending keepalive probes.
    def tcp_keepalive_idle
      optname = {% if flag?(:darwin) %}
        LibC::TCP_KEEPALIVE
      {% else %}
        LibC::TCP_KEEPIDLE
      {% end %}
      getsockopt optname, 0, level: Protocol::TCP
    end

    # Sets the amount of time (in seconds) the connection must be idle before sending keepalive probes.
    def tcp_keepalive_idle=(val : Int)
      optname = {% if flag?(:darwin) %}
        LibC::TCP_KEEPALIVE
      {% else %}
        LibC::TCP_KEEPIDLE
      {% end %}
      setsockopt optname, val, level: Protocol::TCP
      val
    end

    # Returns the amount of time (in seconds) between keepalive probes.
    def tcp_keepalive_interval
      getsockopt LibC::TCP_KEEPINTVL, 0, level: Protocol::TCP
    end

    # Sets the amount of time (in seconds) between keepalive probes.
    def tcp_keepalive_interval=(val : Int)
      setsockopt LibC::TCP_KEEPINTVL, val, level: Protocol::TCP
      val
    end

    # Returns the number of probes sent, without response before dropping the connection.
    def tcp_keepalive_count
      getsockopt LibC::TCP_KEEPCNT, 0, level: Protocol::TCP
    end

    # Sets the number of probes sent, without response before dropping the connection.
    def tcp_keepalive_count=(val : Int)
      setsockopt LibC::TCP_KEEPCNT, val, level: Protocol::TCP
      val
    end
  {% end %}

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl fd, cmd, arg
    raise Errno.new("fcntl() failed") if r == -1
    r
  end

  def fcntl(cmd, arg = 0)
    self.class.fcntl @fd, cmd, arg
  end

  def finalize
    return if closed?

    close rescue nil
  end

  def closed?
    @closed
  end

  def tty?
    LibC.isatty(fd) == 1
  end

  private def unbuffered_read(slice : Bytes)
    read_syscall_helper(slice, "Error reading socket") do
      # `to_i32` is acceptable because `Slice#size` is a Int32
      LibC.recv(@fd, slice, slice.size, 0).to_i32
    end
  end

  private def unbuffered_write(slice : Bytes)
    write_syscall_helper(slice, "Error writing to socket") do |slice|
      LibC.send(@fd, slice, slice.size, 0)
    end
  end

  private def add_read_event(timeout = @read_timeout)
    event = @read_event ||= Crystal::EventLoop.create_fd_read_event(self)
    event.add timeout
    nil
  end

  private def add_write_event(timeout = @write_timeout)
    event = @write_event ||= Crystal::EventLoop.create_fd_write_event(self)
    event.add timeout
    nil
  end

  private def unbuffered_rewind
    raise IO::Error.new("Can't rewind")
  end

  private def unbuffered_close
    return if @closed

    err = nil
    if LibC.close(@fd) != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        err = Errno.new("Error closing socket")
      end
    end

    @closed = true

    @read_event.try &.free
    @read_event = nil
    @write_event.try &.free
    @write_event = nil

    reschedule_waiting

    raise err if err
  end

  private def unbuffered_flush
    # Nothing
  end
end
