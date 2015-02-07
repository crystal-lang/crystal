require "./unix_socket"

class UNIXServer < UNIXSocket
  def initialize(@path : String, socktype =  Socket::Type::STREAM : Socket::Type, backlog = 128)
    File.delete(path) if File.exists?(path)

    sock = LibC.socket(LibC::AF_UNIX, socktype.value, 0)
    raise Errno.new("Error opening socket") if sock <= 0

    addr = LibC::SockAddrUn.new
    addr.family = LibC::AF_UNIX
    addr.path = path.to_unsafe
    if LibC.bind(sock, pointerof(addr) as LibC::SockAddr*, sizeof(LibC::SockAddrUn)) != 0
      LibC.close(sock)
      raise Errno.new("Error binding UNIX server at #{path}")
    end

    if LibC.listen(sock, backlog) != 0
      LibC.close(sock)
      raise Errno.new("Error listening UNIX server at #{path}")
    end

    super sock
  end

  def accept
    client_fd = LibC.accept(@fd, out client_addr, out client_addrlen)
    UNIXSocket.new(client_fd)
  end

  def accept
    sock = accept
    begin
      yield sock
    ensure
      sock.close
    end
  end

  def close
    super
  ensure
    if path = @path
      File.delete(path) if File.exists?(path)
    end
  end
end
