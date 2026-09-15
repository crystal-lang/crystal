require "./tcp_socket"

# A Transmission Control Protocol (TCP/IP) server.
#
# NOTE: To use `TCPServer`, you must explicitly import it with `require "socket"`
#
# Usage example:
# ```
# require "socket"
#
# def handle_client(client)
#   message = client.gets
#   client.puts message
# end
#
# server = TCPServer.new("127.0.0.1", 1234)
# while client = server.accept?
#   spawn handle_client(client)
# end
# ```
#
# Options:
# - *host* local interface to bind on (e.g. `127.0.0.1` or `::1`), or `::` to bind on all local interfaces. Passing a hostname such as `localhost` binds only to the first address family returned by DNS (often `::1`), which will not accept connections directed to `127.0.0.1`.
# - *port* specific port to bind on, or `0` to receive an "ephemeral" (free, assigned by kernel) port.
# - *backlog* to specify how many pending connections are allowed.
# - *reuse_port* to enable multiple processes to bind to the same port (`SO_REUSEPORT`).
class TCPServer < TCPSocket
  include Socket::Server

  # Creates a new `TCPServer`, waiting to be bound.
  def self.new(family : Family = Family::INET)
    super(family)
  end

  # Binds a socket to the *host* and *port* combination.
  #
  # NOTE: When *host* is a hostname such as `localhost`, the server only binds
  # to the first address returned by the system resolver (often `::1` on modern
  # platforms). To bind explicitly to IPv4 loopback, use `127.0.0.1`. To listen
  # on all local interfaces for both IPv4 and IPv6, pass `::` or use `.new(port)`.
  def initialize(host : String, port : Int, backlog : Int = SOMAXCONN, dns_timeout = nil, reuse_port : Bool = false)
    Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)

      self.reuse_address = true
      self.reuse_port = true if reuse_port

      if errno = @fd_lock.reference { system_bind(addrinfo, "#{host}:#{port}") }
        close
        next errno
      end

      if errno = listen(backlog) { |errno| errno }
        close
        next errno
      end
    end
  end

  # Creates a TCPServer from an existing system file descriptor or socket
  # handle.
  #
  # This adopts *fd* into the IO system that will reconfigure it as per the
  # event loop runtime requirements.
  #
  # NOTE: On Windows, the handle must have been created with
  # `WSA_FLAG_OVERLAPPED`.
  def initialize(*, fd : Handle, family : Family = Family::INET)
    super(fd: fd, family: family)
  end

  # Creates a new TCP server, listening on all local interfaces (`::`).
  def self.new(port : Int, backlog = SOMAXCONN, reuse_port = false)
    new("::", port, backlog, reuse_port: reuse_port)
  end

  # Creates a new TCP server and yields it to the block. Eventually closes the
  # server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(host, port, backlog = SOMAXCONN, reuse_port = false, &)
    server = new(host, port, backlog, reuse_port: reuse_port)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Creates a new TCP server, listening on all interfaces, and yields it to the
  # block. Eventually closes the server socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(port : Int, backlog = SOMAXCONN, reuse_port = false, &)
    server = new(port, backlog, reuse_port: reuse_port)
    begin
      yield server
    ensure
      server.close
    end
  end

  # Accepts an incoming connection.
  #
  # Returns the client `TCPSocket` or `nil` if the server is closed after invoking
  # this method.
  #
  # ```
  # require "socket"
  #
  # server = TCPServer.new(2022)
  # loop do
  #   if socket = server.accept?
  #     # handle the client in a fiber
  #     spawn handle_connection(socket)
  #   else
  #     # another fiber closed the server
  #     break
  #   end
  # end
  # ```
  def accept? : TCPSocket?
    return if closed?

    if rs = @fd_lock.read { system_accept }
      sock = TCPSocket.new(handle: rs[0], family: family, type: type, protocol: protocol, blocking: rs[1])
      sock.sync = sync?
      sock
    end
  end
end
