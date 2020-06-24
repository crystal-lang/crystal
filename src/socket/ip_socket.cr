class IPSocket < Socket
  # Returns the `IPAddress` for the local end of the IP socket.
  {% if flag?(:win32) %}
    def local_address
      sockaddr6 = uninitialized LibC::SockaddrIn6
      sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      if LibC.getsockname(socket, sockaddr, pointerof(addrlen).as(Int32*)) != 0
        raise Socket::Error.from_errno("getsockname")
      end

      IPAddress.from(sockaddr, addrlen)
    end
  {% else %}
    def local_address
      sockaddr6 = uninitialized LibC::SockaddrIn6
      sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      if LibC.getsockname(fd, sockaddr, pointerof(addrlen)) != 0
        raise Socket::Error.from_errno("getsockname")
      end

      IPAddress.from(sockaddr, addrlen)
    end
  {% end %}

  # Returns the `IPAddress` for the remote end of the IP socket.
  {% if flag?(:win32) %}
    def remote_address
      sockaddr6 = uninitialized LibC::SockaddrIn6
      sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      if LibC.getpeername(socket, sockaddr, pointerof(addrlen).as(Int32*)) != 0
        raise Socket::Error.from_errno("getpeername")
      end

      IPAddress.from(sockaddr, addrlen)
    end
  {% else %}
    def remote_address
      sockaddr6 = uninitialized LibC::SockaddrIn6
      sockaddr = pointerof(sockaddr6).as(LibC::Sockaddr*)
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      if LibC.getpeername(fd, sockaddr, pointerof(addrlen)) != 0
        raise Socket::Error.from_errno("getpeername")
      end

      IPAddress.from(sockaddr, addrlen)
    end
  {% end %}
end
