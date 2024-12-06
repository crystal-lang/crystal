module Crystal::System::Addrinfo
  alias Handle = LibC::ADDRINFOEXW*

  @addr : LibC::SockaddrIn6

  protected def initialize(addrinfo : Handle)
    @family = ::Socket::Family.from_value(addrinfo.value.ai_family)
    @type = ::Socket::Type.from_value(addrinfo.value.ai_socktype)
    @protocol = ::Socket::Protocol.from_value(addrinfo.value.ai_protocol)
    @size = addrinfo.value.ai_addrlen.to_i

    @addr = uninitialized LibC::SockaddrIn6

    case @family
    when ::Socket::Family::INET6
      addrinfo.value.ai_addr.as(LibC::SockaddrIn6*).copy_to(pointerof(@addr).as(LibC::SockaddrIn6*), 1)
    when ::Socket::Family::INET
      addrinfo.value.ai_addr.as(LibC::SockaddrIn*).copy_to(pointerof(@addr).as(LibC::SockaddrIn*), 1)
    else
      # TODO: (asterite) UNSPEC and UNIX unsupported?
    end
  end

  def system_ip_address : ::Socket::IPAddress
    ::Socket::IPAddress.from(to_unsafe, size)
  end

  def to_unsafe
    pointerof(@addr).as(LibC::Sockaddr*)
  end

  def self.getaddrinfo(domain, service, family, type, protocol, timeout) : Handle
    hints = LibC::ADDRINFOEXW.new
    hints.ai_family = (family || ::Socket::Family::UNSPEC).to_i32
    hints.ai_socktype = type
    hints.ai_protocol = protocol
    hints.ai_flags = 0

    if service.is_a?(Int)
      hints.ai_flags |= LibC::AI_NUMERICSERV
      if service < 0
        raise ::Socket::Addrinfo::Error.from_os_error(nil, WinError::WSATYPE_NOT_FOUND, domain: domain, type: type, protocol: protocol, service: service)
      end
    end

    IOCP::GetAddrInfoOverlappedOperation.run(Crystal::EventLoop.current.iocp_handle) do |operation|
      completion_routine = LibC::LPLOOKUPSERVICE_COMPLETION_ROUTINE.new do |dwError, dwBytes, lpOverlapped|
        orig_operation = IOCP::GetAddrInfoOverlappedOperation.unbox(lpOverlapped)
        LibC.PostQueuedCompletionStatus(orig_operation.iocp, 0, 0, lpOverlapped)
      end

      # NOTE: we handle the timeout ourselves so we don't pass a `LibC::Timeval`
      # to Win32 here
      result = LibC.GetAddrInfoExW(
        Crystal::System.to_wstr(domain), Crystal::System.to_wstr(service.to_s), LibC::NS_DNS, nil, pointerof(hints),
        out addrinfos, nil, operation, completion_routine, out cancel_handle)

      if result == 0
        return addrinfos
      else
        case error = WinError.new(result.to_u32!)
        when .wsa_io_pending?
          # used in `IOCP::OverlappedOperation#try_cancel_getaddrinfo`
          operation.cancel_handle = cancel_handle
        else
          raise ::Socket::Addrinfo::Error.from_os_error("GetAddrInfoExW", error, domain: domain, type: type, protocol: protocol, service: service)
        end
      end

      operation.wait_for_result(timeout) do |error|
        case error
        when .wsa_e_cancelled?
          raise IO::TimeoutError.new("GetAddrInfoExW timed out")
        else
          raise ::Socket::Addrinfo::Error.from_os_error("GetAddrInfoExW", error, domain: domain, type: type, protocol: protocol, service: service)
        end
      end
    end
  end

  def self.next_addrinfo(addrinfo : Handle) : Handle
    addrinfo.value.ai_next
  end

  def self.free_addrinfo(addrinfo : Handle)
    LibC.FreeAddrInfoExW(addrinfo)
  end
end
