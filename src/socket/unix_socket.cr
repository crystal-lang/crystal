require "./delegates"

# A local interprocess communication (UNIX socket) client socket.
#
# Only available on UNIX and UNIX-like operating systems.
#
# Usage example:
# ```
# require "socket"
#
# UNIXSocket.open("/tmp/myapp.sock") do |socket|
#   socket.puts "message"
#   response = socket.gets
# end
# ```
class UNIXSocket < IO
  # Returns the raw socket wrapped by this UNIX socket.
  getter raw : Socket::Raw

  # Creates a `UNIXServer` from a raw socket.
  def initialize(@raw : Socket::Raw, @address : Socket::UNIXAddress)
  end

  # Connects a named UNIX socket, bound to a filesystem pathname.
  def self.new(address : Socket::UNIXAddress) : UNIXSocket
    base = Socket::Raw.new(Socket::Family::UNIX, Socket::Type::STREAM, Socket::Protocol::IP)
    base.connect(address) do |error|
      base.close
      raise error
    end
    new base, address
  end

  # Connects a named UNIX socket, bound to a filesystem pathname.
  def self.new(path : String) : UNIXSocket
    new(Socket::UNIXAddress.new(path))
  end

  # Connects a named UNIX socket, bound to a filesystem pathname and yields it to the block.
  #
  # The socket is closed after the block returns.
  #
  # Returns the return value of the block.
  def self.open(path : Socket::UNIXAddress | String, &block : UNIXSocket ->)
    socket = new(path)

    begin
      yield socket
    ensure
      socket.close
    end
  end

  Socket.delegate_close
  Socket.delegate_io_methods
  Socket.delegate_buffer_sizes

  # Returns a pair of unamed UNIX sockets.
  #
  # ```
  # left, right = UNIXSocket.pair
  #
  # spawn do
  #   # echo server
  #   message = right.gets
  #   right.puts message
  # end
  #
  # left.puts "message"
  # left.gets # => "message"
  # left.close
  # right.close
  # ```
  def self.pair : {UNIXSocket, UNIXSocket}
    fds = uninitialized Int32[2]

    socktype = Socket::Type::STREAM.value
    {% if LibC.has_constant?(:SOCK_CLOEXEC) %}
      socktype |= LibC::SOCK_CLOEXEC
    {% end %}

    if LibC.socketpair(Socket::Family::UNIX, socktype, 0, fds) != 0
      raise Errno.new("socketpair:")
    end

    {
      new(Socket::Raw.new(fds[0], Socket::Family::UNIX, Socket::Type::STREAM, Socket::Protocol::IP), Socket::UNIXAddress.new("")),
      new(Socket::Raw.new(fds[1], Socket::Family::UNIX, Socket::Type::STREAM, Socket::Protocol::IP), Socket::UNIXAddress.new("")),
    }
  end

  # Creates a pair of unamed UNIX sockets (see `pair`) and yields them to the
  # block.
  # Eventually closes both sockets when the block returns.
  #
  # Returns the value of the block.
  #
  # ```
  # UNIXSocket.pair do |left, right|
  #   spawn do
  #     # echo server
  #     message = right.gets
  #     right.puts message
  #   end
  #
  #   left.puts "message"
  #   left.gets # => "message"
  # end
  # ```
  def self.pair(&block : UNIXSocket, UNIXSocket ->)
    left, right = pair
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end

  # Returns the `UNIXAddress` for the local end of the UNIX socket, or `nil` if
  # the socket is closed.
  def local_address? : Socket::UNIXAddress?
    local_address unless closed?
  end

  # Returns the `UNIXAddress` for the local end of the UNIX socket.
  #
  # Raises `Socket::Error` if the socket is closed.
  def local_address : Socket::UNIXAddress
    @address
  end

  # Returns the `UNIXAddress` for the remote end of the UNIX socket, or `nil` if
  # the socket is closed.
  def remote_address? : Socket::UNIXAddress?
    remote_address unless closed?
  end

  # Returns the `UNIXAddress` for the remote end of the UNIX socket.
  #
  # Raises `Socket::Error` if the socket is closed.
  def remote_address : Socket::UNIXAddress
    @address
  end
end
