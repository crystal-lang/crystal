class IPSocket < Socket
  private def getaddrinfo(host, port, family, socktype, protocol = C::IPPROTO_IP)
    hints = C::Addrinfo.new
    hints.family = (family || C::AF_UNSPEC).to_i32
    hints.socktype = socktype
    hints.protocol = protocol
    hints.flags = 0

    ret = C.getaddrinfo(host, port.to_s, pointerof(hints), out addrinfo)
    raise SocketError.new("getaddrinfo: #{String.new(C.gai_strerror(ret))}") if ret == -1

    begin
      yield addrinfo.value
    ensure
      C.freeaddrinfo(addrinfo)
    end
  end
end
