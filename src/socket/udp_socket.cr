require "./delegates"

# A User Datagram Protocol (UDP) socket.
#
# UDP runs on top of the Internet Protocol (IP) and was developed for applications that do
# not require reliability, acknowledgement, or flow control features at the transport layer.
# This simple protocol provides transport layer addressing in the form of UDP ports and an
# optional checksum capability.
#
# UDP is a very simple protocol. Messages, so called datagrams, are sent to other hosts on
# an IP network without the need to set up special transmission channels or data paths
# beforehand. The UDP socket only needs to be opened for communication. It listens for
# incoming messages and sends outgoing messages on request.
#
# This implementation supports both IPv4 and IPv6 addresses. For IPv4 addresses you must use
# `Socket::Family::INET` family (default) or `Socket::Family::INET6` for IPv6 addresses.
#
# Usage example:
#
# ```
# require "socket/udp_socket"
#
# # Create server
# server = UDPSocket.new "localhost", 1234
#
# # Create client and connect to server
# client = UDPSocket.new
# client.connect "localhost", 1234
#
# # Send a text message to server
# client.send "message"
#
# # Receive text message from client
# message, client_addr = server.receive
#
# # Close client and server
# client.close
# server.close
# ```
#
# The `send` methods may sporadically fail with `Errno::ECONNREFUSED` when sending datagrams
# to a non-listening server.
# Wrap with an exception handler to prevent raising. Example:
#
# ```
# begin
#   client.send(message, @destination)
# rescue ex : Errno
#   if ex.errno == Errno::ECONNREFUSED
#     p ex.inspect
#   end
# end
# ```
struct UDPSocket
  # Returns the raw socket wrapped by this UDP socket.
  getter raw : Socket::Raw

  # Creates a `UDPSocket` from a raw socket.
  def initialize(@raw : Socket::Raw)
  end

  # Creates a `UDPSocket` and binds it to any available local address and port.
  def self.new(family : Socket::Family = Socket::Family::INET) : UDPSocket
    new Socket::Raw.new(family, Socket::Type::DGRAM, Socket::Protocol::UDP)
  end

  # Creates a `UDPSocket` and binds it to *address*.
  def self.new(address : Socket::IPAddress, *,
               dns_timeout : Time::Span | Number? = nil, connect_timeout : Time::Span | Number? = nil) : UDPSocket
    new(address.address, address.port, dns_timeout: dns_timeout, connect_timeout: connect_timeout)
  end

  # Creates a `UDPSocket` and binds it to *address* and *port*.
  #
  # If *port* is `0`, any available local port will be chosen.
  def self.new(host : String, port : Int32 = 0, *,
               dns_timeout : Time::Span | Number? = nil, connect_timeout : Time::Span | Number? = nil) : UDPSocket
    Socket::Addrinfo.udp(host, port, dns_timeout) do |addrinfo|
      base = Socket::Raw.new(addrinfo.family, Socket::Type::DGRAM, Socket::Protocol::UDP)
      base.bind(addrinfo)
      base

      new(base)
    end
  end

  # Creates a `UDPSocket` and yields it to the block.
  #
  # The socket will be closed automatically when the block returns.
  def self.open(family : Socket::Family = Socket::Family::INET, *,
                connect_timeout : Time::Span | Number? = nil)
    socket = new(family, connect_timeout: connect_timeout)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  # Creates a `UDPSocket` bound to *address* and yields it to the block.
  #
  # The socket will be closed automatically when the block returns.
  def self.open(address : Socket::IPAddress, *,
                dns_timeout : Time::Span | Number? = nil, connect_timeout : Time::Span | Number? = nil)
    socket = new(host, port, dns_timeout: dns_timeout, connect_timeout: connect_timeout)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  # Creates a `UDPSocket` bound to *address* and *port* and yields it to the block.
  #
  # The socket will be closed automatically when the block returns.
  #
  # If *port* is `0`, any available local port will be chosen.
  def self.open(host : String, port : Int32 = 0, *,
                dns_timeout : Time::Span | Number? = nil, connect_timeout : Time::Span | Number? = nil)
    socket = new(host, port, dns_timeout: dns_timeout, connect_timeout: connect_timeout)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  Socket.delegate_close
  Socket.delegate_buffer_sizes

  # Returns `true` if this socket has been configured to reuse the port (see `SO_REUSEPORT`).
  def reuse_port? : Bool
    @raw.reuse_port?
  end

  # Returns `true` if this socket has been configured to reuse the address (see `SO_REUSEADDR`).
  def reuse_address? : Bool
    @raw.reuse_address?
  end

  # Binds this socket to local *address* and *port*.
  #
  # Raises `Errno` if the binding fails.
  def bind(address : String, port : Int) : Nil
    @raw.bind(address, port)
  end

  # Binds this socket to *port* on any local interface.
  #
  # Raises `Errno` if the binding fails.
  def bind(port : Int) : Nil
    @raw.bind(port)
  end

  # Binds this socket to a local address.
  #
  # Raises `Errno` if the binding fails.
  def bind(addr : Address | Addrinfo) : Nil
    @raw.bind(addr)
  end

  # Connects this UDP socket to remote *address*.
  def connect(address : Socket::IPAddress, *,
              connect_timeout : Time::Span | Number? = nil) : Nil
    @raw.connect(address, connect_timeout: connect_timeout)
  end

  # Connects this UDP socket to remote address *host* and *port*.
  def connect(host : String, port : Int, *,
              dns_timeout : Time::Span | Number? = nil, connect_timeout : Time::Span | Number? = nil) : Nil
    @raw.connect(host, port, dns_timeout: dns_timeout, connect_timeout: connect_timeout)
  end

  # Receives a text message from the previously bound address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind("localhost", 1234)
  #
  # message, client_addr = server.receive
  # ```
  def receive(*, max_message_size = 512) : {String, Socket::IPAddress}
    address = nil
    message = String.new(max_message_size) do |buffer|
      bytes_read, sockaddr, addrlen = @raw.recvfrom(Slice.new(buffer, max_message_size))
      address = Socket::IPAddress.from(sockaddr, addrlen)
      {bytes_read, 0}
    end
    {message, address.not_nil!}
  end

  # Receives a binary message from the previously bound address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind "localhost", 1234
  #
  # message = Bytes.new(32)
  # bytes_read, client_addr = server.receive(message)
  # ```
  def receive(message : Bytes) : {Int32, Socket::IPAddress}
    bytes_read, sockaddr, addrlen = @raw.recvfrom(message)
    {bytes_read, Socket::IPAddress.from(sockaddr, addrlen)}
  end

  def send(message)
    @raw.send(message)
  end

  def send(message, *, to addr : Socket::IPAddress)
    @raw.send(message, to: addr)
  end

  def broadcast=(value : Bool)
    @raw.broadcast = value
  end

  def broadcast? : Bool
    @raw.broadcast?
  end

  # Returns the `IPAddress` for the local end of the IP socket or `nil` if the
  # socket is closed.
  def local_address : Socket::IPAddress?
    local_address unless closed?
  end

  # Returns the `IPAddress` for the local end of the IP socket.
  def local_address : Socket::IPAddress
    @raw.local_address(Socket::IPAddress)
  end

  # Returns the `IPAddress` for the remote end of the IP socket or `nil` if the
  # socket is not connected.
  def remote_address? : Socket::IPAddress?
    remote_address unless closed?
  end

  # Returns the `IPAddress` for the remote end of the IP socket.
  def remote_address : Socket::IPAddress
    @raw.remote_address(Socket::IPAddress)
  end
end
