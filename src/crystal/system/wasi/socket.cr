require "../unix/socket"

module Crystal::System::Socket
  private def initialize_handle(fd, blocking = nil)
  end

  private def system_bind(addr : ::Socket::UNIXAddress, addrstr)
    raise NotImplementedError.new("WASI does not support UNIX sockets")
  end

  private def system_reuse_port?
    false
  end

  private def system_reuse_port=(val : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_reuse_port=" if val
  end

  private def system_broadcast? : Bool
    false
  end

  private def system_broadcast=(val : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_broadcast=" if val
  end

  private def system_linger
    false
  end

  private def system_linger=(val)
    raise NotImplementedError.new "Crystal::System::Socket#system_linger=" if val
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
    flags = Socket.fcntl(fd, LibC::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  private def system_close_on_exec=(arg : Bool)
    Socket.fcntl(fd, LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  def self.fcntl(fd, cmd, arg = 0)
    r = LibC.fcntl fd, cmd, arg
    raise ::Socket::Error.from_errno("fcntl() failed") if r == -1
    r
  end

  private def system_fcntl(cmd, arg = 0)
    Socket.fcntl(fd, cmd, arg)
  end

  private def system_sendfile(file : IO::FileDescriptor, offset : Int64, count : Int64) : Int64
    case result = event_loop.sendfile(self, file.fd, offset, count, 0)
    when Int64
      result
    else
      if result == Errno::ETIMEDOUT
        raise IO::TimeoutError.new("Sendfile timed out", target: self)
      end
      raise IO::Error.from_os_error("sendfile", result, target: self)
    end
  end

  def self.network_interface_to_index(name : String, & : WasiError ->) : Int
    raise NotImplementedError.new("Crystal::System::Socket.network_interface_to_index")
  end

  def self.network_interface_from_index(index : Int, & : WasiError ->) : String
    raise NotImplementedError.new("Crystal::System::Socket.network_interface_from_index")
  end

  {% if flag?(:wasip1) %}
    private def system_bind(addr, addrstr)
      raise NotImplementedError.new("Crystal::System::Socket#system_bind requires wasip2 or later")
    end

    private def system_listen(backlog)
      raise NotImplementedError.new("Crystal::System::Socket#system_listen requires wasip2 or later")
    end

    private def system_send_buffer_size : Int
      raise NotImplementedError.new("Crystal::System::Socket#system_send_buffer_size requires wasip2 or later")
    end

    private def system_send_buffer_size=(val : Int)
      raise NotImplementedError.new("Crystal::System::Socket#system_send_buffer_size= requires wasip2 or later")
    end

    private def system_recv_buffer_size : Int
      raise NotImplementedError.new("Crystal::System::Socket#system_recv_buffer_size requires wasip2 or later")
    end

    private def system_recv_buffer_size=(val : Int)
      raise NotImplementedError.new("Crystal::System::Socket#system_recv_buffer_size= requires wasip2 or later")
    end

    private def system_reuse_address? : Bool
      raise NotImplementedError.new("Crystal::System::Socket#system_reuse_address? requires wasip2 or later")
    end

    private def system_reuse_address=(val : Bool)
      raise NotImplementedError.new("Crystal::System::Socket#system_reuse_address= requires wasip2 or later")
    end

    private def system_keepalive? : Bool
      raise NotImplementedError.new("Crystal::System::Socket#system_keepalive? requires wasip2 or later")
    end

    private def system_keepalive=(val : Bool)
      raise NotImplementedError.new("Crystal::System::Socket#system_keepalive= requires wasip2 or later")
    end

    private def system_getsockopt(optname, optval, level = LibC::SOL_SOCKET, &)
      raise NotImplementedError.new("Crystal::System::Socket#system_getsockopt requires wasip2 or later")
    end

    private def system_getsockopt(optname, optval, level = LibC::SOL_SOCKET)
      raise NotImplementedError.new("Crystal::System::Socket#system_getsockopt requires wasip2 or later")
    end

    private def system_setsockopt(optname, optval, level = LibC::SOL_SOCKET)
      raise NotImplementedError.new("Crystal::System::Socket#system_setsockopt requires wasip2 or later")
    end

    private def system_local_address : ::Socket::IPAddress
      raise NotImplementedError.new("Crystal::System::Socket#system_local_address requires wasip2 or later")
    end

    private def system_remote_address : ::Socket::IPAddress
      raise NotImplementedError.new("Crystal::System::Socket#system_remote_address requires wasip2 or later")
    end
  {% end %}
end
