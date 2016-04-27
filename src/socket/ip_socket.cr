class IPSocket < Socket
  def local_address
    sockaddr = uninitialized LibC::SockaddrIn6
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getsockname(fd, pointerof(sockaddr) as LibC::Sockaddr*, pointerof(addrlen)) != 0
      raise Errno.new("getsockname")
    end

    IPAddress.new(sockaddr, addrlen)
  end

  def remote_address
    sockaddr = uninitialized LibC::SockaddrIn6
    addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

    if LibC.getpeername(fd, pointerof(sockaddr) as LibC::Sockaddr*, pointerof(addrlen)) != 0
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
  private def getaddrinfo(host, port, family, socktype, protocol = LibC::IPPROTO_IP, timeout = nil)
    IPSocket.getaddrinfo(host, port, family, socktype, protocol, timeout) { |ai| yield ai }
  end

  def self.getaddrinfo(host, port, family, socktype, protocol = LibC::IPPROTO_IP, timeout = nil)
    hints = LibC::Addrinfo.new
    hints.ai_family = (family || LibC::AF_UNSPEC).to_i32
    hints.ai_socktype = socktype
    hints.ai_protocol = protocol
    hints.ai_flags = 0

    dns_req = DnsRequestCbArg.new

    # may fire immediately or on the next event loop
    req = Scheduler.create_dns_request(host, port.to_s, pointerof(hints), dns_req) do |err, addr, data|
      dreq = data as DnsRequestCbArg

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
