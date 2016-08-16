class IPSocket < Socket
  # Returns the `IPAddress` for the local end of the IP socket.
  def local_address
    sockaddr = uninitialized LibC::SockaddrIn6
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getsockname(fd, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen)) != 0
      raise Errno.new("getsockname")
    end

    IPAddress.new(sockaddr, addrlen)
  end

  # Returns the `IPAddress` for the remote end of the IP socket.
  def remote_address
    sockaddr = uninitialized LibC::SockaddrIn6
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getpeername(fd, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen)) != 0
      raise Errno.new("getpeername")
    end

    IPAddress.new(sockaddr, addrlen)
  end

  class DnsRequestCbArg
    getter value : Int32 | Pointer(LibC::Addrinfo) | Nil
    @fiber : Fiber

    def initialize
      @fiber = Fiber.current
    end

    def value=(val)
      @value = val
      @fiber.resume
    end
  end

  # Yields LibC::Addrinfo to the block while the block returns false and there are more LibC::Addrinfo results.
  #
  # The block must return true if it succeeded using that addressinfo
  # (to connect or bind, for example), and false otherwise. If it returns false and
  # the LibC::Addrinfo has a next LibC::Addrinfo, it is yielded to the block, and so on.
  private def getaddrinfo(host, port, family, socktype, protocol = Protocol::IP, timeout = nil)
    # Using getaddrinfo from libevent doesn't work well,
    # see https://github.com/crystal-lang/crystal/issues/2660
    #
    # For now it's better to have this working well but maybe a bit slow than
    # having it working fast but something working bad or not seeing some networks.
    IPSocket.getaddrinfo_c_call(host, port, family, socktype, protocol, timeout) { |ai| yield ai }
  end

  # :nodoc:
  def self.getaddrinfo_c_call(host, port, family, socktype, protocol = Protocol::IP, timeout = nil)
    hints = LibC::Addrinfo.new
    hints.ai_family = (family || Family::UNSPEC).to_i32
    hints.ai_socktype = socktype
    hints.ai_protocol = protocol
    hints.ai_flags = 0

    ret = LibC.getaddrinfo(host, port.to_s, pointerof(hints), out addrinfo)
    raise Socket::Error.new("getaddrinfo: #{String.new(LibC.gai_strerror(ret))}") if ret != 0

    begin
      current_addrinfo = addrinfo
      while current_addrinfo
        success = yield current_addrinfo.value
        break if success
        current_addrinfo = current_addrinfo.value.ai_next
      end
    ensure
      LibC.freeaddrinfo(addrinfo)
    end
  end

  # :nodoc:
  def self.getaddrinfo_libevent(host, port, family, socktype, protocol = Protocol::IP, timeout = nil)
    hints = LibC::Addrinfo.new
    hints.ai_family = (family || Family::UNSPEC).to_i32
    hints.ai_socktype = socktype
    hints.ai_protocol = protocol
    hints.ai_flags = 0

    dns_req = DnsRequestCbArg.new

    # may fire immediately or on the next event loop
    req = Scheduler.create_dns_request(host, port.to_s, pointerof(hints), dns_req) do |err, addr, data|
      dreq = data.as(DnsRequestCbArg)

      if err == 0
        dreq.value = addr
      else
        dreq.value = err
      end
    end

    if timeout && req
      spawn do
        sleep timeout.not_nil!
        req.not_nil!.cancel unless dns_req.value
      end
    end

    success = false

    value = dns_req.value
    # BUG: not thread safe.  change when threads are implemented
    unless value
      Scheduler.reschedule
      value = dns_req.value
    end

    if value.is_a?(LibC::Addrinfo*)
      begin
        cur_addr = value
        while cur_addr
          success = yield cur_addr.value

          break if success
          cur_addr = cur_addr.value.ai_next
        end
      ensure
        LibEvent2.evutil_freeaddrinfo value
      end
    elsif value.is_a?(Int)
      if value == LibEvent2::EVUTIL_EAI_CANCEL
        raise IO::Timeout.new("Failed to resolve #{host} in #{timeout} seconds")
      end
      error_message = String.new(LibC.gai_strerror(value))
      raise Socket::Error.new("getaddrinfo: #{error_message}")
    else
      raise "unknown type #{value.inspect}"
    end

    # shouldn't raise
    raise Socket::Error.new("getaddrinfo: unspecified error") unless success
  end
end
