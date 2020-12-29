require "c/arpa/inet"
require "c/netdb"
require "c/netinet/in"
require "c/netinet/tcp"
require "c/sys/socket"
require "c/sys/un"
require "io/evented"

class Socket < IO
  include IO::Buffered
  include IO::Evented

  class Error < IO::Error
    private def self.new_from_errno(message, errno, **opts)
      case errno
      when Errno::ECONNREFUSED
        Socket::ConnectError.new(message, **opts)
      when Errno::EADDRINUSE
        Socket::BindError.new(message, **opts)
      else
        super message, errno, **opts
      end
    end
  end

  class ConnectError < Error
  end

  class BindError < Error
  end

  enum Type
    STREAM    = LibC::SOCK_STREAM
    DGRAM     = LibC::SOCK_DGRAM
    RAW       = LibC::SOCK_RAW
    SEQPACKET = LibC::SOCK_SEQPACKET
  end

  enum Protocol
    IP   = LibC::IPPROTO_IP
    TCP  = LibC::IPPROTO_TCP
    UDP  = LibC::IPPROTO_UDP
    RAW  = LibC::IPPROTO_RAW
    ICMP = LibC::IPPROTO_ICMP
  end

  enum Family : LibC::SaFamilyT
    UNSPEC = LibC::AF_UNSPEC
    UNIX   = LibC::AF_UNIX
    INET   = LibC::AF_INET
    INET6  = LibC::AF_INET6
  end

  # :nodoc:
  SOMAXCONN = 128

  @volatile_fd : Atomic(Int32)

  def fd : Int32
    @volatile_fd.get
  end

  @closed : Bool

  getter family : Family
  getter type : Type
  getter protocol : Protocol

  # Creates a TCP socket. Consider using `TCPSocket` or `TCPServer` unless you
  # need full control over the socket.
  def self.tcp(family : Family, blocking = false)
    new(family, Type::STREAM, Protocol::TCP, blocking)
  end

  # Creates an UDP socket. Consider using `UDPSocket` unless you need full
  # control over the socket.
  def self.udp(family : Family, blocking = false)
    new(family, Type::DGRAM, Protocol::UDP, blocking)
  end

  # Creates an UNIX socket. Consider using `UNIXSocket` or `UNIXServer` unless
  # you need full control over the socket.
  def self.unix(type : Type = Type::STREAM, blocking = false)
    new(Family::UNIX, type, blocking: blocking)
  end

  def initialize(@family, @type, @protocol = Protocol::IP, blocking = false)
    @closed = false
    fd = LibC.socket(family, type, protocol)
    raise Socket::Error.from_errno("Failed to create socket") if fd == -1
    init_close_on_exec(fd)
    @volatile_fd = Atomic.new(fd)

    self.sync = true
    unless blocking
      self.blocking = false
    end
  end

  # Creates a Socket from an existing socket file descriptor.
  def initialize(fd : Int32, @family, @type, @protocol = Protocol::IP, blocking = false)
    @volatile_fd = Atomic.new(fd)
    @closed = false
    init_close_on_exec(fd)

    self.sync = true
    unless blocking
      self.blocking = false
    end
  end

  # Forces opened sockets to be closed on `exec(2)`. Only for platforms that don't
  # support `SOCK_CLOEXEC` (e.g., Darwin).
  protected def init_close_on_exec(fd : Int32)
    {% unless LibC.has_constant?(:SOCK_CLOEXEC) %}
      LibC.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
    {% end %}
  end

  # Connects the socket to a remote host:port.
  #
  # ```
  # require "socket"
  #
  # sock = Socket.tcp(Socket::Family::INET)
  # sock.connect "crystal-lang.org", 80
  # ```
  def connect(host : String, port : Int, connect_timeout = nil)
    Addrinfo.resolve(host, port, @family, @type, @protocol) do |addrinfo|
      connect(addrinfo, timeout: connect_timeout) { |error| error }
    end
  end

  # Connects the socket to a remote address. Raises if the connection failed.
  #
  # ```
  # require "socket"
  #
  # sock = Socket.unix
  # sock.connect Socket::UNIXAddress.new("/tmp/service.sock")
  # ```
  def connect(addr, timeout = nil) : Nil
    connect(addr, timeout) { |error| raise error }
  end

  # Tries to connect to a remote address. Yields an `IO::TimeoutError` or an
  # `Socket::ConnectError` error if the connection failed.
  def connect(addr, timeout = nil)
    timeout = timeout.seconds unless timeout.is_a? Time::Span | Nil
    loop do
      if LibC.connect(fd, addr, addr.size) == 0
        return
      end
      case Errno.value
      when Errno::EISCONN
        return
      when Errno::EINPROGRESS, Errno::EALREADY
        wait_writable(timeout: timeout) do
          return yield IO::TimeoutError.new("connect timed out")
        end
      else
        return yield Socket::ConnectError.from_errno("connect")
      end
    end
  end

  # Binds the socket to a local address.
  #
  # ```
  # require "socket"
  #
  # sock = Socket.tcp(Socket::Family::INET)
  # sock.bind "localhost", 1234
  # ```
  def bind(host : String, port : Int)
    Addrinfo.resolve(host, port, @family, @type, @protocol) do |addrinfo|
      bind(addrinfo, "#{host}:#{port}") { |errno| errno }
    end
  end

  # Binds the socket on *port* to all local interfaces.
  #
  # ```
  # require "socket"
  #
  # sock = Socket.tcp(Socket::Family::INET6)
  # sock.bind 1234
  # ```
  def bind(port : Int)
    Addrinfo.resolve("::", port, @family, @type, @protocol) do |addrinfo|
      bind(addrinfo, "::#{port}") { |errno| errno }
    end
  end

  # Binds the socket to a local address.
  #
  # ```
  # require "socket"
  #
  # sock = Socket.udp(Socket::Family::INET)
  # sock.bind Socket::IPAddress.new("192.168.1.25", 80)
  # ```
  def bind(addr : Socket::Address)
    bind(addr, addr.to_s) { |errno| raise errno }
  end

  # Tries to bind the socket to a local address.
  # Yields an `Socket::BindError` if the binding failed.
  private def bind(addr, addrstr)
    unless LibC.bind(fd, addr, addr.size) == 0
      yield BindError.from_errno("Could not bind to '#{addrstr}'")
    end
  end

  # Tells the previously bound socket to listen for incoming connections.
  def listen(backlog : Int = SOMAXCONN)
    listen(backlog) { |errno| raise errno }
  end

  # Tries to listen for connections on the previously bound socket.
  # Yields an `Socket::Error` on failure.
  def listen(backlog : Int = SOMAXCONN)
    unless LibC.listen(fd, backlog) == 0
      yield Socket::Error.from_errno("Listen failed")
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
  # socket.puts Time.utc
  # socket.close
  # ```
  def accept : Socket
    accept? || raise Socket::Error.new("Closed stream")
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
  #   socket.puts Time.utc
  #   socket.close
  # end
  # ```
  def accept?
    if client_fd = accept_impl
      sock = Socket.new(client_fd, family, type, protocol, blocking)
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
          wait_acceptable
          return if closed?
        else
          raise Socket::Error.from_errno("accept")
        end
      else
        return client_fd
      end
    end
  end

  private def wait_acceptable
    wait_readable(raise_if_closed: false) do
      raise TimeoutError.new("Accept timed out")
    end
  end

  # Sends a message to a previously connected remote address.
  #
  # ```
  # require "socket"
  #
  # sock = Socket.udp(Socket::Family::INET)
  # sock.connect("example.com", 2000)
  # sock.send("text message")
  #
  # sock = Socket.unix(Socket::Type::DGRAM)
  # sock.connect Socket::UNIXAddress.new("/tmp/service.sock")
  # sock.send(Bytes[0])
  # ```
  def send(message) : Int32
    evented_send(message.to_slice, "Error sending datagram") do |slice|
      LibC.send(fd, slice.to_unsafe.as(Void*), slice.size, 0)
    end
  end

  # Sends a message to the specified remote address.
  #
  # ```
  # require "socket"
  #
  # server = Socket::IPAddress.new("10.0.3.1", 2022)
  # sock = Socket.udp(Socket::Family::INET)
  # sock.connect("example.com", 2000)
  # sock.send("text query", to: server)
  # ```
  def send(message, to addr : Address) : Int32
    slice = message.to_slice
    bytes_sent = LibC.sendto(fd, slice.to_unsafe.as(Void*), slice.size, 0, addr, addr.size)
    raise Socket::Error.from_errno("Error sending datagram to #{addr}") if bytes_sent == -1
    # to_i32 is fine because string/slice sizes are an Int32
    bytes_sent.to_i32
  end

  # Receives a text message from the previously bound address.
  #
  # ```
  # require "socket"
  #
  # server = Socket.udp(Socket::Family::INET)
  # server.bind("localhost", 1234)
  #
  # message, client_addr = server.receive
  # ```
  def receive(max_message_size = 512) : {String, Address}
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
  # require "socket"
  #
  # server = Socket.udp(Socket::Family::INET)
  # server.bind("localhost", 1234)
  #
  # message = Bytes.new(32)
  # bytes_read, client_addr = server.receive(message)
  # ```
  def receive(message : Bytes) : {Int32, Address}
    bytes_read, sockaddr, addrlen = recvfrom(message)
    {bytes_read, Address.from(sockaddr, addrlen)}
  end

  protected def recvfrom(bytes)
    sockaddr = Pointer(LibC::SockaddrStorage).malloc.as(LibC::Sockaddr*)
    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = family
    sockaddr.value = copy

    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    bytes_read = evented_read(bytes, "Error receiving datagram") do |slice|
      LibC.recvfrom(fd, slice.to_unsafe.as(Void*), slice.size, 0, sockaddr, pointerof(addrlen))
    end

    {bytes_read, sockaddr, addrlen}
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
    if LibC.shutdown(fd, how) != 0
      raise Socket::Error.from_errno("shutdown #{how}")
    end
  end

  def inspect(io : IO) : Nil
    io << "#<#{self.class}:fd #{fd}>"
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
    getsockopt(LibC::SO_REUSEPORT, 0) do |value|
      return value != 0
    end

    if Errno.value == Errno::ENOPROTOOPT
      return false
    else
      raise Socket::Error.from_errno("getsockopt")
    end
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
  protected def getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    getsockopt(optname, optval, level) { |value| return value }
    raise Socket::Error.from_errno("getsockopt")
  end

  protected def getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, (pointerof(optval).as(Void*)), pointerof(optsize))
    yield optval if ret == 0
    ret
  end

  # NOTE: *optval* is restricted to `Int32` until sizeof works on variables.
  def setsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.setsockopt(fd, level, optname, (pointerof(optval).as(Void*)), optsize)
    raise Socket::Error.from_errno("setsockopt") if ret == -1
    ret
  end

  private def getsockopt_bool(optname, level = LibC::SOL_SOCKET)
    ret = getsockopt optname, 0, level
    ret != 0
  end

  private def setsockopt_bool(optname, optval : Bool, level = LibC::SOL_SOCKET)
    v = optval ? 1 : 0
    ret = setsockopt optname, v, level
    optval
  end

  # Returns `true` if the string represents a valid IPv4 or IPv6 address.
  def self.ip?(string : String)
    addr = LibC::In6Addr.new
    ptr = pointerof(addr).as(Void*)
    LibC.inet_pton(LibC::AF_INET, string, ptr) > 0 || LibC.inet_pton(LibC::AF_INET6, string, ptr) > 0
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

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl fd, cmd, arg
    raise Socket::Error.from_errno("fcntl() failed") if r == -1
    r
  end

  def fcntl(cmd, arg = 0)
    self.class.fcntl fd, cmd, arg
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
    evented_read(slice, "Error reading socket") do
      LibC.recv(fd, slice, slice.size, 0).to_i32
    end
  end

  private def unbuffered_write(slice : Bytes)
    evented_write(slice, "Error writing to socket") do |slice|
      LibC.send(fd, slice, slice.size, 0)
    end
  end

  private def unbuffered_rewind
    raise Socket::Error.new("Can't rewind")
  end

  private def unbuffered_close
    return if @closed

    # Perform libevent cleanup before LibC.close.
    # Using a file descriptor after it has been closed is never defined and can
    # always lead to undefined results. This is not specific to libevent.
    @closed = true
    evented_close

    # Clear the @volatile_fd before actually closing it in order to
    # reduce the chance of reading an outdated fd value
    _fd = @volatile_fd.swap(-1)

    err = nil
    if LibC.close(_fd) != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        err = Socket::Error.from_errno("Error closing socket")
      end
    end

    raise err if err
  end

  private def unbuffered_flush
    # Nothing
  end
end

require "./socket/*"
