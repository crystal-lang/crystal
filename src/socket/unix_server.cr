require "./unix_socket"

class UNIXServer < UNIXSocket
  def initialize(@path : String, socktype = C::SOCK_STREAM, backlog = 128)
    File.delete(path) if File.exists?(path)

    sock = C.socket(C::AF_UNIX, socktype, 0)
    raise Errno.new("Error opening socket") if sock <= 0

    addr = C::SockAddrUn.new
    addr.family = C::AF_UNIX
    addr.path = path.to_unsafe
    if C.bind(sock, pointerof(addr) as C::SockAddr*, sizeof(C::SockAddrUn)) != 0
      raise Errno.new("Error binding UNIX server at #{path}")
    end

    if C.listen(sock, backlog) != 0
      raise Errno.new("Error listening UNIX server at #{path}")
    end

    super sock
  end

  def accept
    client_fd = C.accept(@fd, out client_addr, out client_addrlen)
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
