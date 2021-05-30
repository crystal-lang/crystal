class IPSocket < Socket
  # Returns the `IPAddress` for the local end of the IP socket.
  getter local_address : Socket::IPAddress { system_local_address }

  # Returns the `IPAddress` for the remote end of the IP socket.
  getter remote_address : Socket::IPAddress { system_remote_address }

  def close
    super
    @local_address = nil
    @remote_address = nil
  end
end
