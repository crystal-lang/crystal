require "c/mswsock"
require "c/ioapiset"
require "io/overlapped"

module Crystal::System::Socket
  include IO::Overlapped

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

    Crystal::EventLoop.create_completion_port LibC::HANDLE.new(socket)

    socket
  end

  private def initialize_handle(handle)
    value = 1_u8
    ret = LibC.setsockopt(handle, LibC::SOL_SOCKET, LibC::SO_REUSEADDR, pointerof(value), 1)
    if ret == LibC::SOCKET_ERROR
      raise ::Socket::Error.from_wsa_error("setsockopt")
    end
  end

  private def system_connect(addr, timeout = nil)
    if type.stream?
      system_connect_stream(addr, timeout) { |error| yield error }
    else
      system_connect_connectionless(addr, timeout) { |error| yield error }
    end
  end

  private def system_connect_stream(addr, timeout)
    address = LibC::SockaddrIn6.new
    address.sin6_family = family
    address.sin6_port = 0
    unless LibC.bind(fd, pointerof(address).as(LibC::Sockaddr*), sizeof(LibC::SockaddrIn6)) == 0
      return yield ::Socket::BindError.from_wsa_error("Could not bind to '*'")
    end

    error = overlapped_connect(fd, "ConnectEx") do |overlapped|
      # This is: LibC.ConnectEx(fd, addr, addr.size, nil, 0, nil, overlapped)
      result = Crystal::System::Socket.connect_ex.call(fd, addr.to_unsafe, addr.size, Pointer(Void).null, 0_u32, Pointer(UInt32).null, overlapped)

      if result.zero?
        wsa_error = WinError.wsa_value

        case wsa_error
        when .wsa_io_pending?
          next
        when .wsaeaddrnotavail?
          return yield ::Socket::ConnectError.from_os_error("ConnectEx", wsa_error)
        else
          return yield ::Socket::Error.from_os_error("ConnectEx", wsa_error)
        end
      end
    end

    if error
      yield error
    end
  end

  private def system_connect_connectionless(addr, timeout)
    ret = LibC.connect(fd, addr, addr.size)
    if ret == LibC::SOCKET_ERROR
      yield ::Socket::Error.from_wsa_error("connect")
    end
  end

  private def system_bind(addr, addrstr)
    unless LibC.bind(fd, addr, addr.size) == 0
      yield ::Socket::BindError.from_errno("Could not bind to '#{addrstr}'")
    end
  end

  private def system_listen(backlog)
    unless LibC.listen(fd, backlog) == 0
      yield ::Socket::Error.from_errno("Listen failed")
    end
  end

  protected def system_accept : Handle?
    client_socket = create_handle(family, type, protocol, blocking)
    initialize_handle(client_socket)

    if system_accept(client_socket)
      client_socket
    else
      LibC.closesocket(client_socket)

      nil
    end
  end

  protected def system_accept(client_socket : Handle) : Bool
    address_size = sizeof(LibC::SOCKADDR_STORAGE) + 16
    buffer_size = 0
    output_buffer = Bytes.new(address_size * 2 + buffer_size)

    success = overlapped_accept(fd, "AcceptEx") do |overlapped|
      received_bytes = uninitialized UInt32

      result = Crystal::System::Socket.accept_ex.call(fd, client_socket,
        output_buffer.to_unsafe.as(Void*), buffer_size.to_u32!,
        address_size.to_u32!, address_size.to_u32!, pointerof(received_bytes), overlapped)

      if result.zero?
        error = WinError.wsa_value

        unless error.wsa_io_pending?
          return false
        end
      end
    end

    return false unless success

    # AcceptEx does not automatically set the socket options on the accepted
    # socket to match those of the listening socket, we need to ask for that
    # explicitly with SO_UPDATE_ACCEPT_CONTEXT
    system_setsockopt client_socket, LibC::SO_UPDATE_ACCEPT_CONTEXT, fd

    true
  end

  private def wsa_buffer(bytes)
    wsabuf = LibC::WSABUF.new
    wsabuf.len = bytes.size
    wsabuf.buf = bytes.to_unsafe
    wsabuf
  end

  private def system_send(message : Bytes) : Int32
    wsabuf = wsa_buffer(message)

    bytes = overlapped_write(fd, "WSASend") do |overlapped|
      LibC.WSASend(fd, pointerof(wsabuf), 1, out bytes_sent, 0, overlapped, nil)
    end

    bytes.to_i32
  end

  private def system_send_to(bytes : Bytes, addr : ::Socket::Address)
    wsabuf = wsa_buffer(bytes)
    bytes_sent = overlapped_write(fd, "WSASendTo") do |overlapped|
      LibC.WSASendTo(fd, pointerof(wsabuf), 1, out bytes_sent, 0, addr, addr.size, overlapped, nil)
    end
    raise ::Socket::Error.from_errno("Error sending datagram to #{addr}") if bytes_sent == -1

    # to_i32 is fine because string/slice sizes are an Int32
    bytes_sent.to_i32
  end

  private def system_receive(bytes)
    sockaddr = Pointer(LibC::SOCKADDR_STORAGE).malloc.as(LibC::Sockaddr*)
    # initialize sockaddr with the initialized family of the socket
    copy = sockaddr.value
    copy.sa_family = family
    sockaddr.value = copy

    addrlen = sizeof(LibC::SOCKADDR_STORAGE)

    wsabuf = wsa_buffer(bytes)

    flags = 0_u32
    bytes_read = overlapped_read(fd, "WSARecvFrom") do |overlapped|
      LibC.WSARecvFrom(fd, pointerof(wsabuf), 1, out bytes_received, pointerof(flags), sockaddr, pointerof(addrlen), overlapped, nil)
    end

    {bytes_read.to_i32, sockaddr, addrlen}
  end

  private def system_close_read
    if LibC.shutdown(fd, LibC::SH_RECEIVE) != 0
      raise ::Socket::Error.from_errno("shutdown read")
    end
  end

  private def system_close_write
    if LibC.shutdown(fd, LibC::SH_SEND) != 0
      raise ::Socket::Error.from_errno("shutdown write")
    end
  end

  private def system_reuse_port?
    false
  end

  private def system_reuse_port=(val : Bool)
    raise NotImplementedError.new("Socket#reuse_port=")
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

  def system_getsockopt(handle, optname, optval, level = LibC::SOL_SOCKET)
    optsize = sizeof(typeof(optval))
    ret = LibC.getsockopt(handle, level, optname, pointerof(optval).as(UInt8*), pointerof(optsize))

    if ret.zero?
      yield optval
    else
      raise ::Socket::Error.from_wsa_error("getsockopt #{optname}")
    end

    ret
  end

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
    flags = fcntl(LibC::F_GETFD)
    (flags & LibC::FD_CLOEXEC) == LibC::FD_CLOEXEC
  end

  private def system_close_on_exec=(arg : Bool)
    fcntl(LibC::F_SETFD, arg ? LibC::FD_CLOEXEC : 0)
    arg
  end

  def self.fcntl(fd, cmd, arg = 0)
    ret = LibC.fcntl fd, cmd, arg
    raise Socket::Error.from_errno("fcntl() failed") if ret == -1
    ret
  end

  private def system_tty?
    LibC.isatty(fd) == 1
  end

  private def unbuffered_read(slice : Bytes)
    wsabuf = wsa_buffer(slice)

    bytes_read = overlapped_operation(fd, "WSARecv", read_timeout, connreset_is_error: false) do |overlapped|
      flags = 0_u32
      LibC.WSARecv(fd, pointerof(wsabuf), 1, out bytes_received, pointerof(flags), overlapped, nil)
    end
    bytes_read.to_i32
  end

  private def unbuffered_write(slice : Bytes)
    wsabuf = wsa_buffer(slice)

    bytes = overlapped_write(fd, "WSASend") do |overlapped|
      LibC.WSASend(fd, pointerof(wsabuf), 1, out bytes_sent, 0, overlapped, nil)
    end
    # we could return bytes (from WSAGetOverlappedResult) or bytes_sent
    bytes.to_i32
  end

  def system_close
    handle = @volatile_fd.swap(LibC::INVALID_SOCKET)

    ret = LibC.closesocket(handle)

    if ret != 0
      case Errno.value
      when Errno::EINTR, Errno::EINPROGRESS
        # ignore
      else
        return ::Socket::Error.from_errno("Error closing socket")
      end
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
    getsockopt LibC::SO_KEEPALIVE, 0, level: ::Socket::Protocol::TCP
  end

  private def system_tcp_keepalive_idle=(val : Int)
    setsockopt LibC::SO_KEEPALIVE, val, level: ::Socket::Protocol::TCP
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
