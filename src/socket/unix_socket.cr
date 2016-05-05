class UNIXSocket < Socket
  getter path : String?

  def initialize(@path : String, socktype : Socket::Type = Socket::Type::STREAM)
    sock = create_socket(LibC::AF_UNIX, socktype.value, 0)

    addr = LibC::SockaddrUn.new
    addr.sun_family = LibC::SaFamilyT.new(LibC::AF_UNIX)

    if path.bytesize + 1 > addr.sun_path.size
      raise "Path size exceeds the maximum size of #{addr.sun_path.size - 1} bytes"
    end
    addr.sun_path.to_unsafe.copy_from(path.to_unsafe, path.bytesize + 1)

    if LibC.connect(sock, (pointerof(addr) as LibC::Sockaddr*), sizeof(LibC::SockaddrUn)) != 0
      LibC.close(sock)
      raise Errno.new("Error connecting to '#{path}'")
    end

    super sock
  end

  def initialize(fd : Int32)
    init_close_on_exec fd
    super fd
  end

  def self.open(path, socktype : Socket::Type = Socket::Type::STREAM)
    sock = new(path, socktype)
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def self.pair(socktype : Socket::Type = Socket::Type::STREAM, protocol : Socket::Protocol = Socket::Protocol::IP)
    fds = StaticArray(Int32, 2).new { 0_i32 }
    socktype_value = socktype.value
    {% if LibC.constants.includes?("SOCK_CLOEXEC".id) %}
      socktype_value |= LibC::SOCK_CLOEXEC
    {% end %}
    if LibC.socketpair(LibC::AF_UNIX, socktype_value, protocol.value, fds) != 0
      raise Errno.new("socketpair:")
    end
    fds.map { |fd| UNIXSocket.new(fd) }
  end

  def self.pair(socktype : Socket::Type = Socket::Type::STREAM, protocol : Socket::Protocol = Socket::Protocol::IP)
    left, right = pair(socktype, protocol)
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
