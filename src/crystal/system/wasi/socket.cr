require "c/netdb"
require "c/netinet/tcp"
require "c/sys/socket"
require "io/evented"

module Crystal::System::Socket
  include IO::Evented

  alias Handle = Int32

  private def create_handle(family, type, protocol, blocking) : Handle
    raise NotImplementedError.new "Crystal::System::Socket#create_handle"
  end

  private def initialize_handle(fd)
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

  private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET, &)
    raise NotImplementedError.new "Crystal::System::Socket#system_getsockopt"
  end

  private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)
    raise NotImplementedError.new "Crystal::System::Socket#system_getsockopt"
  end

  private def system_setsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)
    raise NotImplementedError.new "Crystal::System::Socket#system_setsockopt"
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

  def self.socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol) : {Handle, Handle}
    raise NotImplementedError.new("Crystal::System::Socket.socketpair")
  end

  private def system_tty?
    LibC.isatty(fd) == 1
  end

  private def system_close
    # Perform libevent cleanup before LibC.close.
    # Using a file descriptor after it has been closed is never defined and can
    # always lead to undefined results. This is not specific to libevent.
    event_loop.close(self)

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
