class IPSocket < Socket
  def local_address
    sockaddr = uninitialized LibC::SockaddrIn6
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getsockname(fd, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen)) != 0
      raise Errno.new("getsockname")
    end

    IPAddress.new(sockaddr, addrlen)
  end

  def remote_address
    sockaddr = uninitialized LibC::SockaddrIn6
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getpeername(fd, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen)) != 0
      raise Errno.new("getpeername")
    end

    IPAddress.new(sockaddr, addrlen)
  end
end
