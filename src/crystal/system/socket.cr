require "../event_loop/socket"

module Crystal::System::Socket
  # Creates a file descriptor / socket handle
  # private def create_handle(family, type, protocol, blocking) : Handle

  # Initializes a file descriptor / socket handle for use with Crystal Socket
  # private def initialize_handle(fd)

  private def system_connect(addr, timeout = nil)
    event_loop.connect(self, addr, timeout)
  end

  # Tries to bind the socket to a local address.
  # Yields an `Socket::BindError` if the binding failed.
  # private def system_bind(addr, addrstr)

  # private def system_listen(backlog)

  private def system_accept
    event_loop.accept(self)
  end

  private def system_send_to(bytes : Bytes, addr : ::Socket::Address)
    event_loop.send_to(self, bytes, addr)
  end

  private def system_receive_from(bytes : Bytes) : Tuple(Int32, ::Socket::Address)
    event_loop.receive_from(self, bytes)
  end

  # private def system_close_read

  # private def system_close_write

  # private def system_send_buffer_size : Int

  # private def system_send_buffer_size=(val : Int)

  # private def system_recv_buffer_size : Int

  # private def system_recv_buffer_size=(val : Int)

  # private def system_reuse_address? : Bool

  # private def system_reuse_address=(val : Bool)

  # private def system_reuse_port? : Bool

  # private def system_reuse_port=(val : Bool)

  # private def system_broadcast? : Bool

  # private def system_broadcast=(val : Bool)

  # private def system_keepalive? : Bool

  # private def system_keepalive=(val : Bool)

  # private def system_linger

  # private def system_linger=(val)

  # private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET, &)

  # private def system_getsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)

  # private def system_setsockopt(fd, optname, optval, level = LibC::SOL_SOCKET)

  # private def system_blocking?

  # private def system_blocking=(value)

  # private def system_tty?

  # private def system_close_on_exec?

  # private def system_close_on_exec=(arg : Bool)

  # def self.fcntl(fd, cmd, arg = 0)

  # def self.socketpair(type : ::Socket::Type, protocol : ::Socket::Protocol) : {Handle, Handle}

  private def system_read(slice : Bytes) : Int32
    event_loop.read(self, slice)
  end

  private def system_write(slice : Bytes) : Int32
    event_loop.write(self, slice)
  end

  # private def system_close

  # Closes the internal handle without notifying the event loop.
  # This is directly used after the fork of a process to close the
  # parent's Crystal::System::Signal.@@pipe reference before re initializing
  # the event loop. In the case of a fork that will exec there is even
  # no need to initialize the event loop at all.
  # Also used in `Socket#finalize`
  # def socket_close

  private def event_loop? : Crystal::EventLoop::Socket?
    Crystal::EventLoop.current?
  end

  private def event_loop : Crystal::EventLoop::Socket
    Crystal::EventLoop.current
  end

  # IPSocket:

  # private def system_local_address

  # private def system_remote_address

  # TCPSocket:

  # private def system_tcp_keepalive_idle

  # private def system_tcp_keepalive_idle=(val : Int)

  # private def system_tcp_keepalive_interval

  # private def system_tcp_keepalive_interval=(val : Int)

  # private def system_tcp_keepalive_count

  # private def system_tcp_keepalive_count=(val : Int)
end

{% if flag?(:wasi) %}
  require "./wasi/socket"
{% elsif flag?(:unix) %}
  require "./unix/socket"
{% elsif flag?(:win32) %}
  require "./win32/socket"
{% else %}
  {% raise "No Crystal::System::Socket implementation available" %}
{% end %}
