class URI
  # Registry for URI scheme default ports.
  private class DefaultPort
    # A map of schemes and their respective default ports, seeded
    # with some well-known schemes.
    @default_port = {
      "ftp"    => 21,
      "ftps"   => 990,
      "gopher" => 70,
      "http"   => 80,
      "https"  => 443,
      "ldap"   => 389,
      "ldaps"  => 636,
      "nntp"   => 119,
      "scp"    => 22,
      "sftp"   => 22,
      "ssh"    => 22,
      "telnet" => 23,
    }

    # Returns the default port for the given `scheme` if known,
    # otherwise returns `nil`.
    #
    # ```
    # default_port = DefaultPort.new
    # default_port["http"]  # => 80
    # default_port["ponzi"] # => nil
    # ```
    def [](scheme : String?) : Int32?
      return nil if scheme.nil?
      @default_port[normalize(scheme)]?
    end

    # Registers the default `port` for the given `scheme`.
    #
    # ```
    # default_port = DefaultPort.new
    # default_port["ponzi"] # => nil
    # default_port["ponzi"] = 9999
    # default_port["ponzi"] # => 9999
    # ```
    def []=(scheme : String, port : Int32)
      @default_port[normalize(scheme)] = port
    end

    # Unregisters the default `port` for the given `scheme`,
    # returning the previously registered default `port`, or
    # `nil` if no default `port` was registered.
    #
    # ```
    # default_port = DefaultPort.new
    # default_port.delete "http" # => 80
    # default_port["http"]       # => nil
    # ```
    def delete(scheme : String) : Int32?
      @default_port.delete normalize(scheme)
    end

    # Normalizes the given scheme to lowercase.
    private def normalize(scheme : String) : String
      scheme.downcase
    end
  end
end
