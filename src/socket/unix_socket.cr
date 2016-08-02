# A local interprocess communication clientsocket.
#
# Only available on UNIX and UNIX-like operating systems.
#
# Example usage:
# ```
# sock = UNIXSocket.new("/tmp/myapp.sock")
# sock.puts "message"
# response = sock.gets
# sock.close
# ```
class UNIXSocket < Socket
  getter path : String?

  # Connects a named UNIX socket, bound to a filesystem pathname.
  def initialize(@path : String, type : Type = Type::STREAM)
    addr = LibC::SockaddrUn.new
    addr.sun_family = LibC::SaFamilyT.new(Family::UNIX)

    if path.bytesize + 1 > addr.sun_path.size
      raise ArgumentError.new("Path size exceeds the maximum size of #{addr.sun_path.size - 1} bytes")
    end
    addr.sun_path.to_unsafe.copy_from(path.to_unsafe, path.bytesize + 1)

    super create_socket(Family::UNIX, type, 0)

    if LibC.connect(@fd, (pointerof(addr).as(LibC::Sockaddr*)), sizeof(LibC::SockaddrUn)) != 0
      close
      raise Errno.new("Error connecting to '#{path}'")
    end
  end

  protected def initialize(fd : Int32)
    init_close_on_exec fd
    super fd
  end

  # Opens an UNIX socket to a filesystem pathname, yields it to the block, then
  # eventually closes the socket when the block returns.
  #
  # Returns the value of the block.
  def self.open(path, type : Type = Type::STREAM)
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
  def self.pair(type : Type = Type::STREAM)
    fds = StaticArray(Int32, 2).new { 0_i32 }
    socktype = type.value
    {% if LibC.constants.includes?("SOCK_CLOEXEC".id) %}
      socktype |= LibC::SOCK_CLOEXEC
    {% end %}
    if LibC.socketpair(Family::UNIX, socktype, 0, fds) != 0
      raise Errno.new("socketpair:")
    end
    fds.map { |fd| UNIXSocket.new(fd) }
  end

  # Creates a pair of unamed UNIX sockets (see `pair`) and yields them to the
  # block. Eventually closes both sockets when the block returns.
  #
  # Returns the value of the block.
  def self.pair(type : Type = Type::STREAM)
    left, right = pair(type)
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end

  def local_address
    UNIXAddress.new(path.to_s)
  end

  def remote_address
    UNIXAddress.new(path.to_s)
  end
end
