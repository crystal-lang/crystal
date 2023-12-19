require "c/netdb"
require "c/netinet/tcp"
require "c/sys/socket"
require "io/evented"

module Crystal::System::Socket
  include IO::Evented

  alias Handle = Int32

  private def create_handle(family, type, protocol, blocking) : Handle
    fd = LibC.socket(family, type, protocol)
    raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1
    fd
  end

  private def initialize_handle(fd)
    {% unless LibC.has_constant?(:SOCK_CLOEXEC) %}
      # Forces opened sockets to be closed on `exec(2)`. Only for platforms that don't
      # support `SOCK_CLOEXEC` (e.g., Darwin).
      LibC.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
    {% end %}
  end

  private def system_connect(addr, timeout = nil, &)
    timeout = timeout.seconds unless timeout.is_a? ::Time::Span | Nil
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
        return yield ::Socket::ConnectError.from_errno("connect")
      end
    end
  end

  # Tries to bind the socket to a local address.
  # Yields an `Socket::BindError` if the binding failed.
  private def system_bind(addr, addrstr, &)
    unless LibC.bind(fd, addr, addr.size) == 0
      yield ::Socket::BindError.from_errno("Could not bind to '#{addrstr}'")
    end
  end

  private def system_listen(backlog, &)
    unless LibC.listen(fd, backlog) == 0
      yield ::Socket::Error.from_errno("Listen failed")
    end
  end

  private def system_accept
    loop do
      client_fd = LibC.accept(fd, nil, nil)
      if client_fd == -1
        if closed?
          return
        elsif Errno.value == Errno::EAGAIN
          wait_acceptable
          return if closed?
        else
          raise ::Socket::Error.from_errno("accept")
        end
      else
        return client_fd
      end
    end
  end

  private def wait_acceptable
    wait_readable(raise_if_closed: false) do
      raise IO::TimeoutError.new("Accept timed out")
    end
  end

  private def system_send(bytes : Bytes) : Int32
    evented_send(bytes, "Error sending datagram") do |slice|
      LibC.send(fd, slice.to_unsafe.as(Void*), slice.size, 0)
    end
  end

  private def system_send_to(bytes : Bytes, addr : ::Socket::Address)
    bytes_sent = LibC.sendto(fd, bytes.to_unsafe.as(Void*), bytes.size, 0, addr, addr.size)
    raise ::Socket::Error.from_errno("Error sending datagram to #{addr}") if bytes_sent == -1
    # to_i32 is fine because string/slice sizes are an Int32
    bytes_sent.to_i32
  end

  private def system_receive(bytes)
    sockaddr = Pointer(LibC::SockaddrStorage).malloc.as(LibC::Sockaddr*)
    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = family
    sockaddr.value = copy

    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrStorage))

    bytes_read = evented_read(bytes, "Error receiving datagram") do |slice|
      LibC.recvfrom(fd, slice, slice.size, 0, sockaddr, pointerof(addrlen))
    end

    {bytes_read, sockaddr, addrlen}
  end

  private def system_close_read
    if LibC.shutdown(fd, LibC::SHUT_RD) != 0
      raise ::Socket::Error.from_errno("shutdown read")
    end
  end

  private def system_close_write
    if LibC.shutdown(fd, LibC::SHUT_WR) != 0
      raise ::Socket::Error.from_errno("shutdown write")
    end
  end

  private def system_send_buffer_size : Int
    getsockopt LibC::SO_SNDBUF, 0
  end

  private def system_send_buffer_size=(val : Int)
    setsockopt LibC::SO_SNDBUF, val
  end

  private def system_recv_buffer_size : Int
    getsockopt LibC::SO_RCVBUF, 0
  end

  private def system_recv_buffer_size=(val : Int)
    setsockopt LibC::SO_RCVBUF, val
  end

  private def system_reuse_address? : Bool
    getsockopt_bool LibC::SO_REUSEADDR
  end

  private def system_reuse_address=(val : Bool)
    setsockopt_bool LibC::SO_REUSEADDR, val
  end

  private def system_reuse_port? : Bool
    system_getsockopt(fd, LibC::SO_REUSEPORT, 0) do |value|
      return value != 0
    end

    if Errno.value == Errno::ENOPROTOOPT
      false
    else
      raise ::Socket::Error.from_errno("getsockopt")
    end
  end

  private def system_reuse_port=(val : Bool)
    setsockopt_bool LibC::SO_REUSEPORT, val
  end

  private def system_broadcast? : Bool
    getsockopt_bool LibC::SO_BROADCAST
  end

  private def system_broadcast=(val : Bool)
    setsockopt_bool LibC::SO_BROADCAST, val
  end

  private def system_keepalive? : Bool
    getsockopt_bool LibC::SO_KEEPALIVE
  end

  private def system_keepalive=(val : Bool)
    setsockopt_bool LibC::SO_KEEPALIVE, val
  end

  private def system_linger
    v = LibC::Linger.new
    ret = getsockopt LibC::SO_LINGER, v
    ret.l_onoff == 0 ? nil : ret.l_linger
  end

  private def system_linger=(val)
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

  private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET, &)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, pointerof(optval), pointerof(optsize))
    yield optval if ret == 0
    ret
  end

  private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)
    system_getsockopt(fd, optname, optval, level) { |value| return value }
    raise ::Socket::Error.from_errno("getsockopt #{optname}")
  end

  private def system_setsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))

    ret = LibC.setsockopt(fd, level, optname, pointerof(optval), optsize)
    raise ::Socket::Error.from_errno("setsockopt #{optname}") if ret == -1
    ret
  end

  private def system_blocking?
    fcntl(LibC::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  private def system_blocking=(value)
    flags = fcntl(LibC::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(LibC::F_SETFL, flags)
  end

  private def system_close_on_exec?
    flags = fcntl(LibC::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  private def system_close_on_exec=(arg : Bool)
    fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl fd, cmd, arg
    raise ::Socket::Error.from_errno("fcntl() failed") if r == -1
    r
  end

  private def system_tty?
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

  private def system_close
    # Perform libevent cleanup before LibC.close.
    # Using a file descriptor after it has been closed is never defined and can
    # always lead to undefined results. This is not specific to libevent.
    evented_close

    # Clear the @volatile_fd before actually closing it in order to
    # reduce the chance of reading an outdated fd value
    fd = @volatile_fd.swap(-1)

    ret = LibC.close(fd)

    if ret != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        raise ::Socket::Error.from_errno("Error closing socket")
      end
    end
  end

  private def system_local_address
    sockaddr6 = uninitialized LibC::SockaddrIn6
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = sizeof(LibC::SockaddrIn6).to_u32!

    if LibC.getsockname(fd, sockaddr, pointerof(addrlen)) != 0
      raise ::Socket::Error.from_errno("getsockname")
    end

    ::Socket::IPAddress.from(sockaddr, addrlen)
  end

  private def system_remote_address
    sockaddr6 = uninitialized LibC::SockaddrIn6
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = sizeof(LibC::SockaddrIn6).to_u32!

    if LibC.getpeername(fd, sockaddr, pointerof(addrlen)) != 0
      raise ::Socket::Error.from_errno("getpeername")
    end

    ::Socket::IPAddress.from(sockaddr, addrlen)
  end

  {% if flag?(:openbsd) %}
    private def system_tcp_keepalive_idle
      raise NotImplementedError.new("system_tcp_keepalive_idle")
    end

    private def system_tcp_keepalive_idle=(val : Int)
      raise NotImplementedError.new("system_tcp_keepalive_idle=")
    end

    private def system_tcp_keepalive_interval
      raise NotImplementedError.new("system_tcp_keepalive_interval")
    end

    private def system_tcp_keepalive_interval=(val : Int)
      raise NotImplementedError.new("system_tcp_keepalive_interval=")
    end

    private def system_tcp_keepalive_count
      raise NotImplementedError.new("system_tcp_keepalive_count")
    end

    private def system_tcp_keepalive_count=(val : Int)
      raise NotImplementedError.new("system_tcp_keepalive_count=")
    end
  {% else %}
    private def system_tcp_keepalive_idle
      optname = {% if flag?(:darwin) %}
        LibC::TCP_KEEPALIVE
      {% elsif flag?(:netbsd) %}
        LibC::SO_KEEPALIVE
      {% else %}
        LibC::TCP_KEEPIDLE
      {% end %}
      getsockopt optname, 0, level: ::Socket::Protocol::TCP
    end

    private def system_tcp_keepalive_idle=(val : Int)
      optname = {% if flag?(:darwin) %}
        LibC::TCP_KEEPALIVE
      {% elsif flag?(:netbsd) %}
        LibC::SO_KEEPALIVE
      {% else %}
        LibC::TCP_KEEPIDLE
      {% end %}
      setsockopt optname, val, level: ::Socket::Protocol::TCP
      val
    end

    # The amount of time in seconds between keepalive probes.
    private def system_tcp_keepalive_interval
      getsockopt LibC::TCP_KEEPINTVL, 0, level: ::Socket::Protocol::TCP
    end

    private def system_tcp_keepalive_interval=(val : Int)
      setsockopt LibC::TCP_KEEPINTVL, val, level: ::Socket::Protocol::TCP
      val
    end

    # The number of probes sent, without response before dropping the connection.
    private def system_tcp_keepalive_count
      getsockopt LibC::TCP_KEEPCNT, 0, level: ::Socket::Protocol::TCP
    end

    private def system_tcp_keepalive_count=(val : Int)
      setsockopt LibC::TCP_KEEPCNT, val, level: ::Socket::Protocol::TCP
      val
    end
  {% end %}
end
