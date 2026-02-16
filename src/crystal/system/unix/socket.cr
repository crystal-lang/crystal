require "c/netdb"
require "c/netinet/tcp"
require "c/sys/socket"
{% unless flag?(:netbsd) || flag?(:openbsd) %}
  require "c/sys/sendfile"
{% end %}
require "crystal/fd_lock"

module Crystal::System::Socket
  {% if IO.has_constant?(:Evented) %}
    include IO::Evented
  {% end %}

  alias Handle = Int32

  @fd_lock = FdLock.new

  def self.socket(family, type, protocol, blocking) : Handle
    {% if LibC.has_constant?(:SOCK_CLOEXEC) %}
      flags = type.value | LibC::SOCK_CLOEXEC
      flags |= LibC::SOCK_NONBLOCK unless blocking
      fd = LibC.socket(family, flags, protocol)
      raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1
      fd
    {% else %}
      Process.lock_read do
        fd = LibC.socket(family, type, protocol)
        raise ::Socket::Error.from_errno("Failed to create socket") if fd == -1
        FileDescriptor.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
        FileDescriptor.fcntl(fd, LibC::F_SETFL, FileDescriptor.fcntl(fd, LibC::F_GETFL) | LibC::O_NONBLOCK) unless blocking
        fd
      end
    {% end %}
  end

  def self.sendfile(sockfd, fd, offset, count, flags)
    ret = 0
    sent_bytes = 0_i64

    {% if flag?(:darwin) %}
      len = LibC::OffT.new(count)
      ret = LibC.sendfile(fd, sockfd, offset, pointerof(len), nil, 0)
      sent_bytes = len.to_i64
    {% elsif flag?(:dragonflybsd) || flag?(:freebsd) %}
      ret = LibC.sendfile(fd, sockfd, offset, LibC::SizeT.new(count), nil, out sbytes, flags)
      sent_bytes = sbytes.to_i64
    {% elsif flag?(:linux) || flag?(:solaris) %}
      ret = LibC.sendfile(sockfd, fd, pointerof(offset), LibC::SizeT.new(count))
      sent_bytes = ret.to_i64 unless ret == -1
    {% else %}
      Errno.value = Errno::ENOSYS
      ret = -1
    {% end %}

    {ret, sent_bytes}
  end

  private def initialize_handle(fd, blocking = nil)
    {% if Crystal::EventLoop.has_constant?(:Polling) %}
      @__evloop_data = Crystal::EventLoop::Polling::Arena::INVALID_INDEX
    {% end %}
  end

  # Tries to bind the socket to a local address.
  # Yields an `Socket::BindError` if the binding failed.
  private def system_bind(addr, addrstr, &)
    unless @fd_lock.reference { LibC.bind(fd, addr, addr.size) } == 0
      yield ::Socket::BindError.from_errno("Could not bind to '#{addrstr}'")
    end
  end

  private def system_listen(backlog, &)
    unless @fd_lock.reference { LibC.listen(fd, backlog) } == 0
      yield ::Socket::Error.from_errno("Listen failed")
    end
  end

  private def system_accept : {Handle, Bool}?
    @fd_lock.read { event_loop.accept(self) }
  end

  private def system_close_read
    if @fd_lock.reference { LibC.shutdown(fd, LibC::SHUT_RD) } != 0
      raise ::Socket::Error.from_errno("shutdown read")
    end
  end

  private def system_close_write
    if @fd_lock.reference { LibC.shutdown(fd, LibC::SHUT_WR) } != 0
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
    system_getsockopt(LibC::SO_REUSEPORT, 0) do |value|
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

  private def system_getsockopt(optname, optval, level = LibC::SOL_SOCKET, &)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, pointerof(optval), pointerof(optsize))
    yield optval if ret == 0
    ret
  end

  private def system_getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    system_getsockopt(optname, optval, level) { |value| return value }
    raise ::Socket::Error.from_errno("getsockopt #{optname}")
  end

  private def system_setsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))

    ret = @fd_lock.reference do
      LibC.setsockopt(fd, level, optname, pointerof(optval), optsize)
    end
    raise ::Socket::Error.from_errno("setsockopt #{optname}") if ret == -1
    ret
  end

  private def system_blocking?
    FileDescriptor.get_blocking(fd)
  end

  private def system_blocking=(value)
    @fd_lock.reference do
      FileDescriptor.set_blocking(fd, value)
    end
  end

  def self.get_blocking(fd : Handle)
    FileDescriptor.get_blocking(fd)
  end

  def self.set_blocking(fd : Handle, value : Bool)
    FileDescriptor.set_blocking(fd, value)
  end

  private def system_close_on_exec?
    flags = FileDescriptor.fcntl(fd, LibC::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  private def system_close_on_exec=(arg : Bool)
    system_fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  def self.fcntl(fd, cmd, arg = 0)
    FileDescriptor.fcntl(fd, cmd, arg)
  end

  private def system_fcntl(cmd, arg = 0)
    @fd_lock.reference { FileDescriptor.fcntl(fd, cmd, arg) }
  end

  def self.socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol, blocking : Bool) : {Handle, Handle}
    fds = uninitialized Handle[2]

    {% if LibC.has_constant?(:SOCK_CLOEXEC) %}
      flags = type.value | LibC::SOCK_CLOEXEC
      flags |= LibC::SOCK_NONBLOCK unless blocking
      if LibC.socketpair(::Socket::Family::UNIX, flags, protocol, fds) == -1
        raise ::Socket::Error.new("socketpair() failed")
      end
    {% else %}
      Process.lock_read do
        if LibC.socketpair(::Socket::Family::UNIX, type, protocol, fds) == -1
          raise ::Socket::Error.new("socketpair() failed")
        end
        FileDescriptor.fcntl(fds[0], LibC::F_SETFD, LibC::FD_CLOEXEC)
        FileDescriptor.fcntl(fds[1], LibC::F_SETFD, LibC::FD_CLOEXEC)
        unless blocking
          FileDescriptor.fcntl(fds[0], LibC::F_SETFL, FileDescriptor.fcntl(fds[0], LibC::F_GETFL) | LibC::O_NONBLOCK)
          FileDescriptor.fcntl(fds[1], LibC::F_SETFL, FileDescriptor.fcntl(fds[1], LibC::F_GETFL) | LibC::O_NONBLOCK)
        end
      end
    {% end %}

    {fds[0], fds[1]}
  end

  private def system_tty?
    LibC.isatty(fd) == 1
  end

  private def system_close
    if @fd_lock.try_close? { event_loop.shutdown(self) }
      event_loop.close(self)
      @fd_lock.reset
    end
  end

  def socket_close(&)
    # Clear the @volatile_fd before actually closing it in order to
    # reduce the chance of reading an outdated fd value
    return unless fd = close_volatile_fd?

    ret = LibC.close(fd)

    if ret != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        yield
      end
    end
  end

  def close_volatile_fd? : Int32?
    fd = @volatile_fd.swap(-1)
    fd unless fd == -1
  end

  def socket_close
    socket_close do
      raise ::Socket::Error.from_errno("Error closing socket")
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

  private def system_send_to(bytes : Bytes, addr : ::Socket::Address)
    @fd_lock.write { event_loop.send_to(self, bytes, addr) }
  end

  private def system_receive_from(bytes : Bytes) : Tuple(Int32, ::Socket::Address)
    @fd_lock.read { event_loop.receive_from(self, bytes) }
  end

  private def system_sendfile(file : IO::FileDescriptor, offset : Int64, count : Int64) : Int64
    ret = file.@fd_lock.read do
      @fd_lock.write { event_loop.sendfile(self, file.fd, offset, count, flags: 0) }
    end

    case ret
    in Int64
      ret
    in Errno
      if ret == Errno::ETIMEDOUT
        raise IO::TimeoutError.new("Sendfile timed out", target: self)
      else
        raise IO::Error.from_os_error("sendfile", ret, target: self)
      end
    end
  end

  private def system_connect(addr, timeout = nil)
    @fd_lock.write { event_loop.connect(self, addr, timeout) }
  end

  private def system_read(slice : Bytes) : Int32
    @fd_lock.read { event_loop.read(self, slice) }
  end

  private def system_write(slice : Bytes) : Int32
    @fd_lock.write { event_loop.write(self, slice) }
  end
end
