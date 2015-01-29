class UNIXSocket < Socket
  getter :path

  def initialize(@path : String, socktype = LibC::SOCK_STREAM)
    sock = LibC.socket(LibC::AF_UNIX, socktype, 0)
    raise Errno.new("Error opening socket") if sock <= 0

    addr = LibC::SockAddrUn.new
    addr.family = LibC::AF_UNIX
    addr.path = path.to_unsafe
    if LibC.connect(sock, pointerof(addr) as LibC::SockAddr*, sizeof(LibC::SockAddrUn)) != 0
      raise Errno.new("Error connecting to '#{path}'")
    end

    super sock
  end

  def initialize(fd : Int32)
    super fd
  end

  def self.open(path, socktype = LibC::SOCK_STREAM)
    sock = new(path, socktype)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def self.pair(path, socktype = LibC::SOCK_STREAM)
    fds = StaticArray(Int32, 2).new { 0_i32 }
    if LibC.socketpair(LibC::AF_UNIX, socktype, 0, pointerof(fds)) != 0
      raise Errno.new("socketpair:")
    end
    fds.map { |fd| UNIXSocket.new(fd) }
  end

  def self.pair(path, socktype = LibC::SOCK_STREAM)
    left, right = pair(path, socktype)
    begin
      yield left, right
    ensure
      left.close
      right.close
    end
  end
end
