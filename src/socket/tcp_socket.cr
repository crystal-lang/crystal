require "socket"
require "./delegates"

# A Transmission Control Protocol (TCP/IP) socket.
#
# Usage example:
# ```
# require "socket"
#
# TCPSocket.open("localhost", 1234) do |socket|
#   socket.puts "hello!"
#   puts client.gets
# end
# ```
class TCPSocket < IO
  DEFAULT_DNS_TIMEOUT     = 10.seconds
  DEFAULT_CONNECT_TIMEOUT = 15.seconds

  # Returns the raw socket wrapped by this TCP socket.
  getter raw : Socket::Raw

  # Create a `TCPSocket` from a raw socket.
  def initialize(@raw : Socket::Raw)
  end

  # Creates a new TCP connection to a remote socket.
  #
  # *dns_timeout* limits the time for DNS request (if *host* is a hostname and needs
  # to be resolved). *connect_timeout* limits the time to connect to the remote
  # socket. Both values can be a `Time::Span` or a number representing seconds.
  #
  # NOTE: `dns_timeout` is currently ignored.
  def self.new(host : String, port : Int32, *,
               dns_timeout : Time::Span | Number? = DEFAULT_DNS_TIMEOUT,
               connect_timeout : Time::Span | Number? = DEFAULT_CONNECT_TIMEOUT) : TCPSocket
    Socket::Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      raw = Socket::Raw.new(addrinfo.family, Socket::Type::STREAM, Socket::Protocol::TCP)

      if errno = raw.connect(addrinfo, connect_timeout: connect_timeout) { |errno| errno }
        raw.close
        next errno
      end

      new(raw)
    end
  end

  # Creates a new TCP connection to a remote socket.
  #
  # *connect_timeout* limits the time to connect to the remote
  # socket. Both values can be a `Time::Span` or a number representing seconds.
  #
  # *local_address* specifies the local socket used to connect to the remote
  # socket.
  #
  # NOTE: `dns_timeout` is currently ignored.
  def self.new(address : Socket::IPAddress, local_address : Socket::IPAddress? = nil, *,
               connect_timeout : Time::Span | Number? = DEFAULT_CONNECT_TIMEOUT) : TCPSocket
    raw = Socket::Raw.new(addrinfo.family, Socket::Type::STREAM, Socket::Protocol::TCP)

    if local_address
      raw.bind(local_address)
    end

    raw.connect(address, connect_timeout: connect_timeout)

    new(raw)
  end

  # Creates a new TCP connection to a remote socket from a specified local socket.
  #
  # *dns_timeout* limits the time for DNS request (if *host* is a hostname and needs
  # to be resolved). *connect_timeout* limits the time to connect to the remote
  # socket. Both values can be a `Time::Span` or a number representing seconds.
  #
  # NOTE: `dns_timeout` is currently ignored.
  #
  # *local_address* and *local_port* specify the local socket used to connect to
  # the remote socket.
  def self.new(host : String, port : Int32, local_address : String, local_port : Int32, *,
               dns_timeout : Time::Span | Number? = DEFAULT_DNS_TIMEOUT,
               connect_timeout : Time::Span | Number? = DEFAULT_CONNECT_TIMEOUT) : TCPSocket
    Socket::Addrinfo.tcp(host, port, timeout: dns_timeout) do |addrinfo|
      raw = Socket::Raw.new(addrinfo.family, Socket::Type::STREAM, Socket::Protocol::TCP)

      raw.bind(local_address, local_port)

      if errno = raw.connect(addrinfo, connect_timeout: connect_timeout) { |errno| errno }
        raw.close
        next errno
      end

      new(raw)
    end
  end

  # Opens a TCP socket to a remote TCP server, yields it to the block.
  # Eventually closes the socket when the block returns.
  #
  # See `.new` for details about the arguments.
  #
  # Returns the value of the block.
  def self.open(host : String, port : Int32, *,
                dns_timeout : Time::Span | Number? = DEFAULT_DNS_TIMEOUT,
                connect_timeout : Time::Span | Number? = DEFAULT_CONNECT_TIMEOUT)
    socket = new(host, port, dns_timeout: dns_timeout, connect_timeout: connect_timeout)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  # Opens a TCP socket to a remote TCP server, yields it to the block.
  # Eventually closes the socket when the block returns.
  #
  # See `.new` for details about the arguments.
  #
  # Returns the value of the block.
  def self.open(host : String, port : Int32, local_address : String, local_port : Int32, *,
                dns_timeout : Time::Span | Number? = DEFAULT_DNS_TIMEOUT,
                connect_timeout : Time::Span | Number? = DEFAULT_CONNECT_TIMEOUT)
    socket = new(host, port, local_address, local_port, dns_timeout: dns_timeout, connect_timeout: connect_timeout)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  # Opens a TCP socket to a remote TCP server, yields it to the block.
  # Eventually closes the socket when the block returns.
  #
  # See `.new` for details about the arguments.
  #
  # Returns the value of the block.
  def self.open(address : Socket::IPAddress, local_address : Socket::IPAddress? = nil, *,
                connect_timeout : Time::Span | Number? = DEFAULT_CONNECT_TIMEOUT)
    socket = new(address, local_address, connect_timeout: connect_timeout)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  Socket.delegate_close
  Socket.delegate_io_methods
  Socket.delegate_tcp_options

  # Returns the `IPAddress` for the local end of the IP socket, or `nil` if the
  # socket is closed.
  def local_address? : Socket::IPAddress?
    local_address unless closed?
  end

  # Returns the `IPAddress` for the local end of the IP socket.
  #
  # Raises `Socket::Error` if the socket is closed.
  def local_address : Socket::IPAddress
    @raw.local_address(Socket::IPAddress)
  end

  # Returns the `IPAddress` for the remote end of the IP socket, or `nil` if the
  # socket is closed.
  def remote_address? : Socket::IPAddress?
    remote_address unless closed?
  end

  # Returns the `IPAddress` for the remote end of the IP socket.
  #
  # Raises `Socket::Error` if the socket is closed.
  def remote_address : Socket::IPAddress
    @raw.remote_address(Socket::IPAddress)
  end
end
