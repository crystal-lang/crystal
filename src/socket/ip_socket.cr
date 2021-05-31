class IPSocket < Socket
  # Returns the `IPAddress` for the local end of the IP socket.
  def local_address
    system_local_address
  end

  # Returns the `IPAddress` for the remote end of the IP socket.
  def remote_address
    system_remote_address
  end
end
