require "socket"
require "uri"

abstract class HTTP::Client::Transport
  abstract def connect(uri : URI, request : Request) : IO

  class Default < Transport
    include Socket::TCPConfig

    def connect(uri : URI, request : Request) : IO
      host = uri.host
      raise "Empty host" if !host || host.empty?
      port = uri.port || ((scheme = uri.scheme) && URI.default_port(scheme)) || raise "Unknown scheme: #{uri.scheme}"

      transport = TCPTransport.new(host, port.to_i)
      transport.dns_timeout = @dns_timeout
      transport.connect_timeout = @connect_timeout
      transport.read_timeout = @read_timeout
      transport.connect(uri, request)
    end
  end

  class TCPTransport < Transport
    include Socket::TCPConfig

    # Returns the target host.
    #
    # ```
    # client = HTTP::Client.new "www.example.com"
    # client.host # => "www.example.com"
    # ```
    getter host : String

    # Returns the target port.
    #
    # ```
    # client = HTTP::Client.new "www.example.com"
    # client.port # => 80
    # ```
    getter port : Int32

    getter socket : TCPSocket do
      TCPSocket.new(@host, @port, dns_timeout: @dns_timeout, connect_timeout: @connect_timeout).tap do |socket|
        socket.read_timeout = @read_timeout
        socket.sync = false
      end
    end

    def connect(uri : URI, request : Request) : IO
      socket
    end
  end
end
