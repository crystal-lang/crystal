class IPSocket < Socket::Raw
  # Returns the `IPAddress` for the local end of the IP socket or `nil` if it
  # is not connected.
  def local_address?
    local_address unless closed?
  end

  # Returns the `IPAddress` for the local end of the IP socket.
  #
  # Raises if the socket is not connected.
  def local_address
    sockaddr6 = uninitialized LibC::SockaddrIn6
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getsockname(fd, sockaddr, pointerof(addrlen)) != 0
      raise Errno.new("getsockname")
    end

    Socket::IPAddress.from(sockaddr, addrlen)
  end

  # Returns the `IPAddress` for the remote end of the IP socket or `nil` if it
  # is not connected.
  def remote_address?
    remote_address unless closed?
  end

  # Returns the `IPAddress` for the remote end of the IP socket.
  #
  # Raises if the socket is not connected.
  def remote_address
    sockaddr6 = uninitialized LibC::SockaddrIn6
    sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getpeername(fd, sockaddr, pointerof(addrlen)) != 0
      raise Errno.new("getpeername")
    end

    Socket::IPAddress.from(sockaddr, addrlen)
  end
end
