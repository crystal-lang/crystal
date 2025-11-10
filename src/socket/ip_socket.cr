# NOTE: To use `IPSocket`, you must explicitly import it with `require "socket/ip_socket"`
class IPSocket < Socket
  # Returns the `IPAddress` for the local end of the IP socket.
  getter local_address : Socket::IPAddress { system_local_address }

  # Returns the `IPAddress` for the remote end of the IP socket.
  getter remote_address : Socket::IPAddress { system_remote_address }

  def close
    super
  ensure
    @local_address = nil
    @remote_address = nil
  end

  def connect(addr, timeout = nil, &)
    super(addr, timeout) { |error| yield error }
  ensure
    @local_address = nil
    @remote_address = nil
  end

  def bind(addr)
    super(addr)
  ensure
    @local_address = nil
    @remote_address = nil
  end

  def ipv6_only? : Bool
    raise Socket::Error.new("Unsupported IP address family: #{family}. For use with IPv6 only") unless family.inet6?
    getsockopt_bool(LibC::IPV6_V6ONLY, level: LibC::IPPROTO_IPV6)
  end

  def ipv6_only=(val : Bool) : Bool
    raise Socket::Error.new("Unsupported IP address family: #{family}. For use with IPv6 only") unless family.inet6?
    sock.setsockopt_bool LibC::IPV6_V6ONLY, val, level: LibC::IPPROTO_IPV6
  end
end
