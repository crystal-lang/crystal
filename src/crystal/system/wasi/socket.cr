require "c/netdb"
require "c/netinet/tcp"
require "c/sys/socket"
require "io/evented"

module Crystal::System::Socket
  include IO::Evented

  alias Handle = Int32

  private def initialize_handle(fd, blocking = nil)
  end

  # Tries to bind the socket to a local address.
  # Yields an `Socket::BindError` if the binding failed.
  private def system_bind(addr, addrstr, &)
    raise NotImplementedError.new "Crystal::System::Socket#system_bind"
  end

  private def system_listen(backlog, &)
    raise NotImplementedError.new "Crystal::System::Socket#system_listen"
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
    raise NotImplementedError.new "Crystal::System::Socket#system_send_buffer_size"
  end

  private def system_send_buffer_size=(val : Int)
    raise NotImplementedError.new "Crystal::System::Socket#system_send_buffer_size="
  end

  private def system_recv_buffer_size : Int
    raise NotImplementedError.new "Crystal::System::Socket#system_recv_buffer_size"
  end

  private def system_recv_buffer_size=(val : Int)
    raise NotImplementedError.new "Crystal::System::Socket#system_recv_buffer_size="
  end

  private def system_reuse_address? : Bool
    raise NotImplementedError.new "Crystal::System::Socket#system_reuse_address?"
  end

  private def system_reuse_address=(val : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_reuse_address="
  end

  private def system_reuse_port?
    raise NotImplementedError.new "Crystal::System::Socket#system_reuse_port?"
  end

  private def system_reuse_port=(val : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_reuse_port="
  end

  private def system_broadcast? : Bool
    raise NotImplementedError.new "Crystal::System::Socket#system_broadcast?"
  end

  private def system_broadcast=(val : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_broadcast="
  end

  private def system_keepalive? : Bool
    raise NotImplementedError.new "Crystal::System::Socket#system_keepalive?"
  end

  private def system_keepalive=(val : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_keepalive="
  end

  private def system_linger
    raise NotImplementedError.new "Crystal::System::Socket#system_linger"
  end

  private def system_linger=(val)
    raise NotImplementedError.new "Crystal::System::Socket#system_linge="
  end

  private def system_getsockopt(optname, optval, level = LibC::SOL_SOCKET, &)
    raise NotImplementedError.new "Crystal::System::Socket#system_getsockopt"
  end

  private def system_getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    raise NotImplementedError.new "Crystal::System::Socket#system_getsockopt"
  end

  private def system_setsockopt(optname, optval, level = LibC::SOL_SOCKET)
    raise NotImplementedError.new "Crystal::System::Socket#system_setsockopt"
  end

  private def system_blocking?
    Socket.get_blocking(fd)
  end

  private def system_blocking=(value)
    Socket.set_blocking(fd, value)
  end

  def self.get_blocking(fd : Handle)
    fcntl(fd, LibC::F_GETFL) & LibC::O_NONBLOCK == 0
  end

  def self.set_blocking(fd : Handle, value : Bool)
    flags = fcntl(fd, LibC::F_GETFL)
    if value
      flags &= ~LibC::O_NONBLOCK
    else
      flags |= LibC::O_NONBLOCK
    end
    fcntl(fd, LibC::F_SETFL, flags)
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

  private def system_fcntl(cmd, arg = 0)
    FileDescriptor.system_fcntl(fd, cmd, arg)
  end

  private def system_tty?
    LibC.isatty(fd) == 1
  end

  private def system_close
    event_loop.close(self)
  end

  def socket_close
    # Clear the @volatile_fd before actually closing it in order to
    # reduce the chance of reading an outdated fd value
    return unless fd = close_volatile_fd?

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

  def close_volatile_fd? : Int32?
    fd = @volatile_fd.swap(-1)
    fd unless fd == -1
  end

  private def system_local_address
    raise NotImplementedError.new "Crystal::System::Socket#system_local_address"
  end

  private def system_remote_address
    raise NotImplementedError.new "Crystal::System::Socket#system_remote_address"
  end

  private def system_tcp_keepalive_idle
    raise NotImplementedError.new("Crystal::System::Socket#system_tcp_keepalive_idle")
  end

  private def system_tcp_keepalive_idle=(val : Int)
    raise NotImplementedError.new("Crystal::System::Socket#system_tcp_keepalive_idle=")
  end

  private def system_tcp_keepalive_interval
    raise NotImplementedError.new("Crystal::System::Socket#system_tcp_keepalive_interval")
  end

  private def system_tcp_keepalive_interval=(val : Int)
    raise NotImplementedError.new("Crystal::System::Socket#system_tcp_keepalive_interval=")
  end

  private def system_tcp_keepalive_count
    raise NotImplementedError.new("Crystal::System::Socket#system_tcp_keepalive_count")
  end

  private def system_tcp_keepalive_count=(val : Int)
    raise NotImplementedError.new("Crystal::System::Socket#system_tcp_keepalive_count=")
  end
end
