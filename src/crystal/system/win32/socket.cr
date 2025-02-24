require "c/mswsock"
require "c/ioapiset"
require "crystal/system/win32/iocp"

module Crystal::System::Socket
  alias Handle = LibC::SOCKET

  # Initialize WSA
  def self.initialize_wsa
    # version 2.2
    wsa_version = 0x202
    err = LibC.WSAStartup(wsa_version, out wsadata)
    unless err.zero?
      raise IO::Error.from_os_error("WSAStartup", WinError.new(err.to_u32))
    end

    if wsadata.wVersion != wsa_version
      raise IO::Error.new("Unsuitable version of Winsock.dll: 0x#{wsadata.wVersion.to_s(16)}")
    end
  end

  def self.load_extension_function(socket, guid, proc_type)
    function_pointer = uninitialized Pointer(Void)
    result = LibC.WSAIoctl(
      socket,
      LibC::SIO_GET_EXTENSION_FUNCTION_POINTER,
      pointerof(guid),
      sizeof(LibC::GUID),
      pointerof(function_pointer),
      sizeof(Pointer(Void)),
      out bytes,
      nil,
      nil
    )
    if result == LibC::SOCKET_ERROR
      raise ::Socket::Error.from_wsa_error("WSAIoctl")
    end
    proc_type.new(function_pointer, Pointer(Void).null)
  end

  class_getter connect_ex
  class_getter accept_ex
  @@connect_ex = uninitialized LibC::ConnectEx
  @@accept_ex = uninitialized LibC::AcceptEx

  # Some overlapped socket functions are not part of the Winsock specification.
  # The implementation is provider-specific and needs to be queried at runtime
  # with WSAIoctl.
  # Crystal's socket implementation only uses Microsoft's default provider,
  # so the same function can be shared across all sockets because they all use
  # the same provider.
  #
  # https://stackoverflow.com/questions/37355397/why-is-the-wsarecvmsg-function-implemented-as-a-function-pointer-and-can-this-po/37356935#37356935
  def self.initialize_extension_functions
    initialize_wsa

    # Create dummy socket for WSAIoctl
    socket = LibC.socket(LibC::AF_INET, LibC::SOCK_STREAM, 0)
    if socket == LibC::INVALID_SOCKET
      raise ::Socket::Error.from_wsa_error("socket")
    end

    @@connect_ex = load_extension_function(socket, LibC::WSAID_CONNECTEX, LibC::ConnectEx)
    @@accept_ex = load_extension_function(socket, LibC::WSAID_ACCEPTEX, LibC::AcceptEx)

    result = LibC.closesocket(socket)
    unless result.zero?
      raise ::Socket::Error.from_wsa_error("closesocket")
    end
  end

  initialize_extension_functions

  private def create_handle(family, type, protocol, blocking) : Handle
    socket = LibC.WSASocketW(family, type, protocol, nil, 0, LibC::WSA_FLAG_OVERLAPPED)
    if socket == LibC::INVALID_SOCKET
      raise ::Socket::Error.from_wsa_error("WSASocketW")
    end

    Crystal::EventLoop.current.create_completion_port LibC::HANDLE.new(socket)

    socket
  end

  private def initialize_handle(handle)
    unless @family.unix?
      system_getsockopt(handle, LibC::SO_REUSEADDR, 0) do |value|
        if value == 0
          system_setsockopt(handle, LibC::SO_EXCLUSIVEADDRUSE, 1)
        end
      end
    end
  end

  private def system_connect(addr, timeout = nil)
    if type.stream?
      system_connect_stream(addr, timeout)
    else
      system_connect_connectionless(addr, timeout)
    end
  end

  private def system_connect_stream(addr, timeout)
    address = LibC::SockaddrIn6.new
    address.sin6_family = family
    address.sin6_port = 0
    unless LibC.bind(fd, pointerof(address).as(LibC::Sockaddr*), sizeof(LibC::SockaddrIn6)) == 0
      return ::Socket::BindError.from_wsa_error("Could not bind to '*'")
    end

    error = event_loop.connect(self, addr, timeout)

    if error
      return error
    end

    # from https://learn.microsoft.com/en-us/windows/win32/winsock/sol-socket-socket-options:
    #
    # > This option is used with the ConnectEx, WSAConnectByList, and
    # > WSAConnectByName functions. This option updates the properties of the
    # > socket after the connection is established. This option should be set
    # > if the getpeername, getsockname, getsockopt, setsockopt, or shutdown
    # > functions are to be used on the connected socket.
    optname = LibC::SO_UPDATE_CONNECT_CONTEXT
    if LibC.setsockopt(fd, LibC::SOL_SOCKET, optname, nil, 0) == LibC::SOCKET_ERROR
      return ::Socket::Error.from_wsa_error("setsockopt #{optname}")
    end
  end

  # :nodoc:
  def overlapped_connect(socket, method, timeout, &)
    IOCP::WSAOverlappedOperation.run(socket) do |operation|
      result = yield operation

      if result == 0
        case error = WinError.wsa_value
        when .wsa_io_pending?
          # the operation is running asynchronously; do nothing
        when .wsaeaddrnotavail?
          return ::Socket::ConnectError.from_os_error("ConnectEx", error)
        else
          return ::Socket::Error.from_os_error("ConnectEx", error)
        end
      else
        return nil
      end

      operation.wait_for_result(timeout) do |error|
        case error
        when .wsa_io_incomplete?, .wsaeconnrefused?
          return ::Socket::ConnectError.from_os_error(method, error)
        when .error_operation_aborted?
          # FIXME: Not sure why this is necessary
          return ::Socket::ConnectError.from_os_error(method, error)
        end
      end

      nil
    end
  end

  private def system_connect_connectionless(addr, timeout)
    ret = LibC.connect(fd, addr, addr.size)
    if ret == LibC::SOCKET_ERROR
      ::Socket::Error.from_wsa_error("connect")
    end
  end

  private def system_bind(addr, addrstr, &)
    unless LibC.bind(fd, addr, addr.size) == 0
      yield ::Socket::BindError.from_wsa_error("Could not bind to '#{addrstr}'")
    end
  end

  private def system_listen(backlog, &)
    unless LibC.listen(fd, backlog) == 0
      yield ::Socket::Error.from_wsa_error("Listen failed")
    end
  end

  def system_accept(& : Handle -> Bool) : Handle?
    client_socket = create_handle(family, type, protocol, blocking)
    initialize_handle(client_socket)

    if yield client_socket
      client_socket
    else
      LibC.closesocket(client_socket)

      nil
    end
  end

  def overlapped_accept(socket, method, &)
    IOCP::WSAOverlappedOperation.run(socket) do |operation|
      result = yield operation

      if result == 0
        case error = WinError.wsa_value
        when .wsa_io_pending?
          # the operation is running asynchronously; do nothing
        else
          return false
        end
      else
        return true
      end

      operation.wait_for_result(read_timeout) do |error|
        case error
        when .wsa_io_incomplete?, .wsaenotsock?
          return false
        when .error_operation_aborted?
          raise IO::TimeoutError.new("#{method} timed out")
        end
      end

      true
    end
  end

  private def system_close_read
    if LibC.shutdown(fd, LibC::SH_RECEIVE) != 0
      raise ::Socket::Error.from_wsa_error("shutdown read")
    end
  end

  private def system_close_write
    if LibC.shutdown(fd, LibC::SH_SEND) != 0
      raise ::Socket::Error.from_wsa_error("shutdown write")
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

  # SO_REUSEADDR, as used in posix, is always assumed on windows
  # the SO_REUSEADDR flag on windows is the equivalent of SO_REUSEPORT on linux
  # https://learn.microsoft.com/en-us/windows/win32/winsock/using-so-reuseaddr-and-so-exclusiveaddruse#application-strategies
  private def system_reuse_address? : Bool
    true
  end

  private def system_reuse_address=(val : Bool)
    raise NotImplementedError.new("Crystal::System::Socket#system_reuse_address=") unless val
  end

  private def system_reuse_port?
    getsockopt_bool LibC::SO_REUSEADDR
  end

  private def system_reuse_port=(val : Bool)
    if val
      setsockopt_bool LibC::SO_EXCLUSIVEADDRUSE, false
      setsockopt_bool LibC::SO_REUSEADDR, true
    else
      setsockopt_bool LibC::SO_REUSEADDR, false
      setsockopt_bool LibC::SO_EXCLUSIVEADDRUSE, true
    end
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

  private def system_getsockopt(handle, optname, optval, level = LibC::SOL_SOCKET, &)
    optsize = sizeof(typeof(optval))
    ret = LibC.getsockopt(handle, level, optname, pointerof(optval).as(UInt8*), pointerof(optsize))
    yield optval if ret == 0
    ret
  end

  private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)
    system_getsockopt(fd, optname, optval, level) { |value| return value }
    raise ::Socket::Error.from_wsa_error("getsockopt #{optname}")
  end

  # :nodoc:
  def system_setsockopt(handle, optname, optval, level = LibC::SOL_SOCKET)
    optsize = sizeof(typeof(optval))

    ret = LibC.setsockopt(handle, level, optname, pointerof(optval).as(UInt8*), optsize)
    raise ::Socket::Error.from_wsa_error("setsockopt #{optname}") if ret == LibC::SOCKET_ERROR
    ret
  end

  @blocking = true

  # WSA does not provide a direct way to query the blocking mode of a file descriptor.
  # The best option seems to be just keeping track in an instance variable.
  # This becomes invalid if the blocking mode was changed directly on the
  # socket handle without going through `Socket#blocking=`.
  private def system_blocking?
    @blocking
  end

  private def system_blocking=(@blocking)
    mode = blocking ? 1_u32 : 0_u32
    ret = LibC.WSAIoctl(fd, LibC::FIONBIO, pointerof(mode), sizeof(UInt32), nil, 0, out bytes_returned, nil, nil)
    raise ::Socket::Error.from_wsa_error("WSAIoctl") unless ret.zero?
  end

  private def system_close_on_exec?
    false
  end

  private def system_close_on_exec=(arg : Bool)
    raise NotImplementedError.new "Crystal::System::Socket#system_close_on_exec=" if arg
  end

  def self.fcntl(fd, cmd, arg = 0)
    raise NotImplementedError.new "Crystal::System::Socket.fcntl"
  end

  def self.socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol) : {Handle, Handle}
    raise NotImplementedError.new("Crystal::System::Socket.socketpair")
  end

  private def system_tty?
    LibC.GetConsoleMode(LibC::HANDLE.new(fd), out _) != 0
  end

  def system_close
    socket_close
  end

  private def socket_close(&)
    handle = @volatile_fd.swap(LibC::INVALID_SOCKET)

    ret = LibC.closesocket(handle)

    if ret != 0
      case err = WinError.wsa_value
      when WinError::WSAEINTR, WinError::WSAEINPROGRESS
        # ignore
      else
        yield err
      end
    end
  end

  def socket_close
    socket_close do |err|
      raise ::Socket::Error.from_os_error("Error closing socket", err)
    end
  end

  private def system_local_address
    sockaddr6 = uninitialized LibC::SockaddrIn6
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = sizeof(LibC::SockaddrIn6)

    ret = LibC.getsockname(fd, sockaddr, pointerof(addrlen))
    if ret == LibC::SOCKET_ERROR
      raise ::Socket::Error.from_wsa_error("getsockname")
    end

    ::Socket::IPAddress.from(sockaddr, addrlen)
  end

  private def system_remote_address
    sockaddr6 = uninitialized LibC::SockaddrIn6
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = sizeof(LibC::SockaddrIn6)

    ret = LibC.getpeername(fd, sockaddr, pointerof(addrlen))
    if ret == LibC::SOCKET_ERROR
      raise ::Socket::Error.from_wsa_error("getpeername")
    end

    ::Socket::IPAddress.from(sockaddr, addrlen)
  end

  private def system_tcp_keepalive_idle
    getsockopt LibC::TCP_KEEPIDLE, 0, level: ::Socket::Protocol::TCP
  end

  private def system_tcp_keepalive_idle=(val : Int)
    setsockopt LibC::TCP_KEEPIDLE, val, level: ::Socket::Protocol::TCP
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
end
