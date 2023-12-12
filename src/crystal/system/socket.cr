module Crystal::System::Socket
  # Creates a file descriptor / socket handle
  # private def create_handle(family, type, protocol, blocking) : Handle

  # Initializes a file descriptor / socket handle for use with Crystal Socket
  # private def initialize_handle(fd)

  # private def system_connect(addr, timeout = nil)

  # Tries to bind the socket to a local address.
  # Yields an `Socket::BindError` if the binding failed.
  # private def system_bind(addr, addrstr)

  # private def system_listen(backlog)

  # private def system_accept

  # private def system_send(bytes : Bytes) : Int32

  # private def system_send_to(bytes : Bytes, addr : ::Socket::Address)

  # private def system_receive(bytes)

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

  # private def unbuffered_read(slice : Bytes)

  # private def unbuffered_write(slice : Bytes)

  # private def system_close

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
