class URI
  # Global registry for URI scheme default ports.
  private class DefaultPort
    # Well-known schemes and their respective default ports.
    @@default_port = {
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
      @@default_port[scheme.downcase]?
    end

    # Registers the default `port` for the given `scheme`.
    #
    # ```
    # default_port = DefaultPort.new
    # default_port["ponzi"] # => nil
    # default_port["ponzi"] = 9999
    # default_port["ponzi"] # => 9999
    # ```
    def []=(scheme : String, port : Int32?)
      if port
        @@default_port[scheme.downcase] = port
      else
        @@default_port.delete scheme.downcase
      end
    end
  end
end
