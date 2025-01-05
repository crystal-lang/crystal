# A local interprocess communication clientsocket.
#
# Available on UNIX-like operating systems, and Windows 10 Build 17063 or above.
# Not all features are supported on Windows.
#
# NOTE: To use `UNIXSocket`, you must explicitly import it with `require "socket"`
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
class UNIXSocket < Socket
  getter path : String?

  # Connects a named UNIX socket, bound to a filesystem pathname.
  def initialize(@path : String, type : Type = Type::STREAM)
    super(Family::UNIX, type, Protocol::IP)

    connect(UNIXAddress.new(path)) do |error|
      close
      raise error
    end
  end

  protected def initialize(family : Family, type : Type)
    super family, type, Protocol::IP
  end

  # Creates a UNIXSocket from an already configured raw file descriptor
  def initialize(*, fd : Handle, type : Type = Type::STREAM, @path : String? = nil)
    super fd, Family::UNIX, type, Protocol::IP
  end

  # Opens an UNIX socket to a filesystem pathname, yields it to the block, then
  # eventually closes the socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(path, type : Type = Type::STREAM, &)
    sock = new(path, type)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  # Returns a pair of unnamed UNIX sockets.
  #
  # [Not supported on Windows](https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/#unsupportedunavailable).
  #
  # ```
  # require "socket"
  #
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
  def self.pair(type : Type = Type::STREAM) : {UNIXSocket, UNIXSocket}
    Crystal::System::Socket
      .socketpair(type, Protocol::IP)
      .map { |fd| UNIXSocket.new(fd: fd, type: type) }
  end

  # Creates a pair of unnamed UNIX sockets (see `pair`) and yields them to the
  # block. Eventually closes both sockets when the block returns.
  #
  # Returns the value of the block.
  #
  # [Not supported on Windows](https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/#unsupportedunavailable).
  def self.pair(type : Type = Type::STREAM, &)
    left, right = pair(type)
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end

  def local_address : Socket::UNIXAddress
    UNIXAddress.new(path.to_s)
  end

  def remote_address : Socket::UNIXAddress
    UNIXAddress.new(path.to_s)
  end

  def receive(max_message_size = 512) : {String, UNIXAddress}
    message, address = super(max_message_size)
    {message, address.as(UNIXAddress)}
  end
end
