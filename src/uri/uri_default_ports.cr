class URI
  # Global registry for URI scheme default ports.
  private class DefaultPorts
    # Well-known schemes and their respective default ports.
    @@default_ports = {
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
    # default_ports = DefaultPorts.new
    # default_ports["http"]  # => 80
    # default_ports["ponzi"] # => nil
    # ```
    def [](scheme : String?) : Int32?
      return nil if scheme.nil?
      @@default_ports[scheme.downcase]?
    end

    # Globally registers the default `port` for the given `scheme`.
    #
    # ```
    # default_ports = DefaultPorts.new
    # default_ports["ponzi"] # => nil
    # default_ports["ponzi"] = 9999
    # default_ports["ponzi"] # => 9999
    # ```
    def []=(scheme : String, port : Int32?)
      if port
        @@default_ports[scheme.downcase] = port
      else
        @@default_ports.delete scheme
      end
    end
  end
end
