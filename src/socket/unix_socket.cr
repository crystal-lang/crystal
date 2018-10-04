# A local interprocess communication clientsocket.
#
# Only available on UNIX and UNIX-like operating systems.
#
# Example usage:
# ```
# require "socket"
#
# sock = UNIXSocket.new("/tmp/myapp.sock")
# sock.puts "message"
# response = sock.gets
# sock.close
# ```
class UNIXSocket < Socket::Raw
  getter path : String?

  # Connects a named UNIX socket, bound to a filesystem pathname.
  def initialize(@path : String, type : Socket::Type = Socket::Type::STREAM)
    super(Socket::Family::UNIX, type, Socket::Protocol::IP)

    connect(Socket::UNIXAddress.new(path)) do |error|
      close
      raise error
    end
  end

  protected def initialize(family : Socket::Family, type : Socket::Type)
    super family, type, Socket::Protocol::IP
  end

  protected def initialize(fd : Int32, type : Socket::Type, @path : String? = nil)
    super fd, Socket::Family::UNIX, type, Socket::Protocol::IP
  end

  # Opens an UNIX socket to a filesystem pathname, yields it to the block, then
  # eventually closes the socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(path, type : Socket::Type = Socket::Type::STREAM)
    sock = new(path, type)
    begin
      yield sock
    ensure
      sock.close
    end
  end

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
  # ```
  def self.pair(type : Socket::Type = Socket::Type::STREAM)
    fds = uninitialized Int32[2]

    socktype = type.value
    {% if LibC.has_constant?(:SOCK_CLOEXEC) %}
      socktype |= LibC::SOCK_CLOEXEC
    {% end %}

    if LibC.socketpair(Socket::Family::UNIX, socktype, 0, fds) != 0
      raise Errno.new("socketpair:")
    end

    {UNIXSocket.new(fds[0], type), UNIXSocket.new(fds[1], type)}
  end

  # Creates a pair of unamed UNIX sockets (see `pair`) and yields them to the
  # block. Eventually closes both sockets when the block returns.
  #
  # Returns the value of the block.
  def self.pair(type : Socket::Type = Socket::Type::STREAM)
    left, right = pair(type)
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end

  def local_address
    Socket::UNIXAddress.new(path.to_s)
  end

  def remote_address
    Socket::UNIXAddress.new(path.to_s)
  end

  def receive
    bytes_read, sockaddr, addrlen = recvfrom
    {bytes_read, Socket::UNIXAddress.from(sockaddr, addrlen)}
  end
end
