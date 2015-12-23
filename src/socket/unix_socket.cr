class UNIXSocket < Socket
  getter :path

  def initialize(@path : String, socktype = Socket::Type::STREAM : Socket::Type)
    sock = create_socket(LibC::AF_UNIX, socktype.value, 0)

    addr = LibC::SockAddrUn.new
    addr.family = typeof(addr.family).new(LibC::AF_UNIX)
    if path.bytesize + 1 > addr.path.size
      raise "Path size exceeds the maximum size of #{addr.path.size - 1} bytes"
    end
    addr.path.to_unsafe.copy_from(path.to_unsafe, path.bytesize + 1)
    if LibC.connect(sock, (pointerof(addr) as LibC::SockAddr*), sizeof(LibC::SockAddrUn)) != 0
      LibC.close(sock)
      raise Errno.new("Error connecting to '#{path}'")
    end

    super sock
  end

  def initialize(fd : Int32)
    init_close_on_exec fd
    super fd
  end

  def self.open(path, socktype = Socket::Type::STREAM : Socket::Type)
    sock = new(path, socktype)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def self.pair(socktype = Socket::Type::STREAM : Socket::Type, protocol = Socket::Protocol::IP : Socket::Protocol)
    fds = StaticArray(Int32, 2).new { 0_i32 }
    if LibC.socketpair(LibC::AF_UNIX, socktype.value | LibC::SOCK_CLOEXEC, protocol.value, pointerof(fds)) != 0
      raise Errno.new("socketpair:")
    end
    fds.map { |fd| UNIXSocket.new(fd) }
  end

  def self.pair(socktype = Socket::Type::STREAM : Socket::Type, protocol = Socket::Protocol::IP : Socket::Protocol)
    left, right = pair(socktype, protocol)
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end

  def addr
    Addr.new("AF_UNIX", path.to_s)
  end

  def peeraddr
    Addr.new("AF_UNIX", path.to_s)
  end
end
