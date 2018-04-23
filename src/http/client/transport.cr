require "socket"
require "uri"

abstract class HTTP::Client::Transport
  abstract def connect(uri : URI, request : Request) : IO

  class Default < Transport
    @connect_timeout : Float64?
    @dns_timeout : Float64?
    @read_timeout : Float64?

    # Set the number of seconds to wait when reading before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.read_timeout = 1.5
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def read_timeout=(read_timeout : Number)
      @read_timeout = read_timeout.to_f
    end

    # Set the read timeout with a `Time::Span`, to wait when reading before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.read_timeout = 5.minutes
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def read_timeout=(read_timeout : Time::Span)
      self.read_timeout = read_timeout.total_seconds
    end

    # Set the number of seconds to wait when connecting, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.connect_timeout = 1.5
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def connect_timeout=(connect_timeout : Number)
      @connect_timeout = connect_timeout.to_f
    end

    # Set the open timeout with a `Time::Span` to wait when connecting, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.connect_timeout = 5.minutes
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def connect_timeout=(connect_timeout : Time::Span)
      self.connect_timeout = connect_timeout.total_seconds
    end

    # **This method has no effect right now**
    #
    # Set the number of seconds to wait when resolving a name, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.dns_timeout = 1.5
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def dns_timeout=(dns_timeout : Number)
      @dns_timeout = dns_timeout.to_f
    end

    # **This method has no effect right now**
    #
    # Set the number of seconds to wait when resolving a name with a `Time::Span`, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.dns_timeout = 1.5.seconds
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def dns_timeout=(dns_timeout : Time::Span)
      self.dns_timeout = dns_timeout.total_seconds
    end

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

    property connect_timeout : Float64?
    property dns_timeout : Float64?
    property read_timeout : Float64?

    def initialize(@host : String, @port : Int32)
    end

    # Set the number of seconds to wait when reading before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.read_timeout = 1.5
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def read_timeout=(read_timeout : Number)
      @read_timeout = read_timeout.to_f
    end

    # Set the read timeout with a `Time::Span`, to wait when reading before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.read_timeout = 5.minutes
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def read_timeout=(read_timeout : Time::Span)
      self.read_timeout = read_timeout.total_seconds
    end

    # Set the number of seconds to wait when connecting, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.connect_timeout = 1.5
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def connect_timeout=(connect_timeout : Number)
      @connect_timeout = connect_timeout.to_f
    end

    # Set the open timeout with a `Time::Span` to wait when connecting, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.connect_timeout = 5.minutes
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def connect_timeout=(connect_timeout : Time::Span)
      self.connect_timeout = connect_timeout.total_seconds
    end

    # **This method has no effect right now**
    #
    # Set the number of seconds to wait when resolving a name, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.dns_timeout = 1.5
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def dns_timeout=(dns_timeout : Number)
      @dns_timeout = dns_timeout.to_f
    end

    # **This method has no effect right now**
    #
    # Set the number of seconds to wait when resolving a name with a `Time::Span`, before raising an `IO::Timeout`.
    #
    # ```
    # client = HTTP::Client.new("example.org")
    # client.dns_timeout = 1.5.seconds
    # begin
    #   response = client.get("/")
    # rescue IO::Timeout
    #   puts "Timeout!"
    # end
    # ```
    def dns_timeout=(dns_timeout : Time::Span)
      self.dns_timeout = dns_timeout.total_seconds
    end

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
