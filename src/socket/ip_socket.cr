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
end
