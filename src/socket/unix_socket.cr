class UNIXSocket < Socket
  getter :path

  def initialize(@path : String, socktype = C::SOCK_STREAM)
    sock = C.socket(C::AF_UNIX, socktype, 0)
    raise Errno.new("Error opening socket") if sock <= 0

    addr = C::SockAddrUn.new
    addr.family = C::AF_UNIX
    addr.path = path.to_unsafe
    if C.connect(sock, pointerof(addr) as C::SockAddr*, sizeof(C::SockAddrUn)) != 0
      raise Errno.new("Error connecting to '#{path}'")
    end

    super sock
  end

  def initialize(fd : Int32)
    super fd
  end

  def self.open(path, socktype = C::SOCK_STREAM)
    sock = new(path, socktype)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def self.pair(path, socktype = C::SOCK_STREAM)
    fds = StaticArray(Int32, 2).new { 0_i32 }
    if C.socketpair(C::AF_UNIX, socktype, 0, pointerof(fds)) != 0
      raise Errno.new("socketpair:")
    end
    fds.map { |fd| UNIXSocket.new(fd) }
  end

  def self.pair(path, socktype = C::SOCK_STREAM)
    left, right = pair(path, socktype)
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end
end
