class IPSocket < Socket
  # Yields C::Addrinfo to the block while the block returns true and there are more C::Addrinfo results.
  #
  # The block must return true if it succeeded using that addressinfo
  # (to connect or bind, for example), and false otherwise. If it returns false and
  # the C::Addrinfo has a next C::Addrinfo, it is yielded to the block, and so on.
  private def getaddrinfo(host, port, family, socktype, protocol = C::IPPROTO_IP)
    hints = C::Addrinfo.new
    hints.family = (family || C::AF_UNSPEC).to_i32
    hints.socktype = socktype
    hints.protocol = protocol
    hints.flags = 0

    ret = C.getaddrinfo(host, port.to_s, pointerof(hints), out addrinfo)
    raise SocketError.new("getaddrinfo: #{String.new(C.gai_strerror(ret))}") if ret == -1

    begin
      current_addrinfo = addrinfo
      while current_addrinfo
        success = yield current_addrinfo.value
        break if success
        current_addrinfo = current_addrinfo.value.next
      end
    ensure
      C.freeaddrinfo(addrinfo)
    end
  end
end
