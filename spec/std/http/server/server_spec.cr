require "../spec_helper"
require "http/server"
require "http/client"
require "../../../support/ssl"
require "../../../support/channel"

# TODO: Windows networking in the interpreter requires #12495
{% if flag?(:interpreted) && flag?(:win32) %}
  pending HTTP::Server
  {% skip_file %}
{% end %}

# TODO: replace with `HTTP::Client.get` once it supports connecting to Unix socket (#2735)
private def unix_request(path)
  UNIXSocket.open(path) do |io|
    HTTP::Client.new(io).get(path).body
  end
end

private def unused_port
  TCPServer.open(Socket::IPAddress::UNSPECIFIED, 0) do |server|
    server.local_address.port
  end
end

private class SilentErrorHTTPServer < HTTP::Server
  private def handle_exception(e)
  end
end

private def requestize(string)
  string.gsub('\n', "\r\n")
end

describe HTTP::Server do
  it "binds to unused port" do
    server = HTTP::Server.new { |ctx| }
    address = server.bind_unused_port
    address.port.should_not eq(0)

    server.close

    server = HTTP::Server.new { |ctx| }
    port = server.bind_tcp(0).port
    port.should_not eq(0)
  ensure
    server.close if server
  end

  it "doesn't raise on accept after close #2692" do
    server = HTTP::Server.new { }
    server.bind_unused_port

    run_server(server) do
      server.close
    end
  end

  it "closes the server" do
    server = HTTP::Server.new { }
    address = server.bind_unused_port
    ch = Channel(SpecChannelStatus).new

    spawn do
      server.listen
      ch.send :end
    end

    # wait for the server to start listening, and a little longer
    # so the spawn that performs the accept has chance to run
    while !server.listening?
      Fiber.yield
    end
    sleep 0.1.seconds

    schedule_timeout ch

    TCPSocket.open(address.address, address.port) { }

    # wait before closing the server
    sleep 0.1.seconds
    server.close

    ch.receive.should eq SpecChannelStatus::End
  end

  it "reuses the TCP port (SO_REUSEPORT)" do
    s1 = HTTP::Server.new { |ctx| }
    address = s1.bind_unused_port(reuse_port: true)

    s2 = HTTP::Server.new { |ctx| }
    s2.bind_tcp(address.port, reuse_port: true)

    s1.close
    s2.close
  end

  it "binds to different ports" do
    server = HTTP::Server.new do |context|
      context.response.print "Test Server (#{context.request.local_address})"
    end

    tcp_server = TCPServer.new("127.0.0.1", 0)
    server.bind tcp_server
    address1 = tcp_server.local_address

    address2 = server.bind_unused_port

    address1.should_not eq address2

    run_server(server) do
      HTTP::Client.get("http://#{address2}/").body.should eq "Test Server (#{address2})"
      HTTP::Client.get("http://#{address1}/").body.should eq "Test Server (#{address1})"
      HTTP::Client.get("http://#{address1}/").body.should eq "Test Server (#{address1})"
    end
  end

  it "handles Expect: 100-continue correctly when body is read" do
    server = HTTP::Server.new do |context|
      context.response << context.request.body.not_nil!.gets_to_end
    end

    address = server.bind_unused_port

    run_server(server) do
      TCPSocket.open(address.address, address.port) do |socket|
        socket << requestize(<<-HTTP
          POST / HTTP/1.1
          Expect: 100-continue
          Content-Length: 5

          HTTP
        )
        socket << "\r\n"
        socket.flush

        response = HTTP::Client::Response.from_io(socket)
        response.status_code.should eq(100)

        socket << "hello"
        socket.flush

        response = HTTP::Client::Response.from_io(socket)
        response.status_code.should eq(200)
        response.body.should eq("hello")
      end
    end
  end

  it "handles Expect: 100-continue correctly when body isn't read" do
    server = HTTP::Server.new do |context|
      context.response.respond_with_status(400, "I don't want your body")
    end

    address = server.bind_unused_port

    run_server(server) do
      TCPSocket.open(address.address, address.port) do |socket|
        socket << requestize(<<-HTTP
          POST / HTTP/1.1
          Expect: 100-continue
          Content-Length: 5

          HTTP
        )
        socket << "\r\n"
        socket.flush

        response = HTTP::Client::Response.from_io(socket)
        response.status_code.should eq(400)
        response.body.should eq("400 I don't want your body\n")
      end
    end
  end

  it "lists addresses" do
    server = HTTP::Server.new { }

    tcp_server = TCPServer.new("127.0.0.1", 0)
    addresses = [server.bind_unused_port, server.bind_unused_port, tcp_server.local_address]
    server.bind tcp_server

    server.addresses.should eq addresses
  ensure
    server.try &.close
  end

  describe "#bind" do
    it "fails after listen" do
      server = HTTP::Server.new { }
      server.bind_unused_port

      run_server(server) do
        expect_raises(Exception, "Can't add socket to running server") do
          server.bind_unused_port
        end
      end
    end

    it "fails after close" do
      server = HTTP::Server.new { }
      server.bind_unused_port

      run_server(server) do
        server.close

        expect_raises(Exception, "Can't add socket to closed server") do
          server.bind_unused_port
        end
      end
    end

    describe "with URI" do
      it "accepts URI" do
        server = HTTP::Server.new { }

        begin
          port = unused_port
          address = server.bind URI.parse("tcp://127.0.0.1:#{port}")
          address.should eq Socket::IPAddress.new("127.0.0.1", port)
        ensure
          server.close
        end
      end

      it "accepts String" do
        server = HTTP::Server.new { }

        begin
          port = unused_port
          address = server.bind "tcp://127.0.0.1:#{port}"
          address.should eq Socket::IPAddress.new("127.0.0.1", port)
        ensure
          server.close
        end
      end

      it "parses TCP" do
        server = HTTP::Server.new { }

        begin
          port = unused_port
          address = server.bind "tcp://127.0.0.1:#{port}"
          address.should eq Socket::IPAddress.new("127.0.0.1", port)
        ensure
          server.close
        end
      end

      it "parses SSL" do
        server = HTTP::Server.new { }

        private_key = datapath("openssl", "openssl.key")
        certificate = datapath("openssl", "openssl.crt")

        begin
          port = unused_port
          expect_raises(ArgumentError, "missing CA certificate") do
            server.bind "tls://127.0.0.1:#{port}?key=#{private_key}&cert=#{certificate}&verify_mode=force-peer"
          end

          address = server.bind "tls://127.0.0.1:#{port}?key=#{private_key}&cert=#{certificate}&ca=#{certificate}"
          address.should eq Socket::IPAddress.new("127.0.0.1", port)

          port = unused_port
          address = server.bind "ssl://127.0.0.1:#{port}?key=#{private_key}&cert=#{certificate}&ca=#{certificate}"
          address.should eq Socket::IPAddress.new("127.0.0.1", port)
        ensure
          server.close
        end
      end

      it "fails SSL with invalid params" do
        server = HTTP::Server.new { }

        private_key = datapath("openssl", "openssl.key")
        certificate = datapath("openssl", "openssl.crt")

        begin
          expect_raises(ArgumentError, "missing private key") { server.bind "tls://127.0.0.1:8081" }
          expect_raises(OpenSSL::Error, "No such file or directory") { server.bind "tls://127.0.0.1:8081?key=foo.key" }
          expect_raises(ArgumentError, "missing certificate") { server.bind "tls://127.0.0.1:8081?key=#{private_key}" }
        ensure
          server.close
        end
      end

      it "fails with unknown scheme" do
        server = HTTP::Server.new { }

        begin
          expect_raises(ArgumentError, "Unsupported socket type: udp") do
            server.bind "udp://127.0.0.1:8081"
          end
        ensure
          server.close
        end
      end
    end
  end

  describe "#bind_tls" do
    it "binds SSL server context" do
      server = HTTP::Server.new do |context|
        context.response.puts "Test Server (#{context.request.local_address})"
        context.response.close
      end

      server_context, client_context = ssl_context_pair

      socket = OpenSSL::SSL::Server.new(TCPServer.new("127.0.0.1", 0), server_context)
      server.bind socket
      ip_address1 = server.bind_tls "127.0.0.1", 0, server_context
      ip_address2 = socket.local_address

      run_server(server) do
        HTTP::Client.get("https://#{ip_address1}", tls: client_context).body.should eq "Test Server (#{ip_address1})\n"
        HTTP::Client.get("https://#{ip_address2}", tls: client_context).body.should eq "Test Server (#{ip_address2})\n"
      end
    end
  end

  describe "#listen" do
    it "fails after listen" do
      server = HTTP::Server.new { }
      server.bind_unused_port

      run_server(server) do
        expect_raises(Exception, "Can't start running server") do
          server.listen
        end
      end
    end

    it "fails after close" do
      server = HTTP::Server.new { }
      server.bind_unused_port

      run_server(server) do
        server.close
        server.listening?.should be_false

        expect_raises(Exception, "Can't re-start closed server") do
          server.listen
        end
      end
    end
  end

  {% if flag?(:unix) %}
    describe "#bind_unix" do
      it "binds to different unix sockets" do
        path1 = File.tempname
        path2 = File.tempname

        begin
          server = HTTP::Server.new do |context|
            context.response.print "Test Server (#{context.request.local_address})"
            context.response.close
          end

          socket1 = UNIXServer.new(path1)
          server.bind socket1
          socket2 = server.bind_unix path2

          run_server(server) do
            unix_request(path1).should eq "Test Server (#{path1})"
            unix_request(path2).should eq "Test Server (#{path2})"
          end

          File.exists?(path1).should be_false
          File.exists?(path2).should be_false
        ensure
          File.delete?(path1)
          File.delete?(path2)
        end
      end
    end
  {% end %}

  it "handles exception during SSL handshake (#6577)" do
    server = SilentErrorHTTPServer.new do |context|
      context.response.print "ok"
      context.response.close
    end

    server_context, client_context = ssl_context_pair
    address = server.bind_tls "localhost", server_context

    run_server(server) do |server_done|
      3.times do
        # Perform multiple wrong calls together and check
        # that the server is still able to respond.
        3.times do
          empty_context = OpenSSL::SSL::Context::Client.new
          TCPSocket.open(address.address, address.port) do |socket|
            expect_raises(OpenSSL::SSL::Error) do
              OpenSSL::SSL::Socket::Client.new(socket, empty_context)
            end
          end
        end

        HTTP::Client.get("https://#{address}/", tls: client_context).body.should eq "ok"
      end

      server.closed?.should be_false
      select
      when ret = server_done.receive
        fail("Server finished with #{ret}")
      else
      end
    end
  end

  it "can process simultaneous SSL handshakes" do
    server = HTTP::Server.new do |context|
      context.response.print "ok"
    end

    server_context, client_context = ssl_context_pair
    address = server.bind_tls "localhost", server_context

    run_server(server) do
      ch = Channel(Nil).new

      spawn do
        TCPSocket.open(address.address, address.port) do |socket|
          ch.send nil
          ch.receive
        end
      end

      begin
        ch.receive
        client = HTTP::Client.new(address.address, address.port, client_context)
        client.read_timeout = client.connect_timeout = 3.seconds
        client.get("/").body.should eq "ok"
      ensure
        ch.send nil
      end
    end
  end

  describe "#close" do
    it "closes gracefully" do
      server = HTTP::Server.new do |context|
        context.response.flush
        context.response.puts "foo"
        context.response.flush

        context.response.puts "bar"
      end

      address = server.bind_unused_port

      run_server(server) do
        TCPSocket.open(address.address, address.port) do |socket|
          socket << "GET / HTTP/1.1\r\n\r\n"

          while true
            line = socket.gets || break
            break if line.empty?
          end

          socket = HTTP::ChunkedContent.new(socket)

          socket.gets.should eq "foo"

          server.close

          socket.closed?.should be_false
          socket.gets.should eq "bar"
        end
      end
    end
  end

  describe "#remote_address / #local_address" do
    it "for http server" do
      remote_address = nil
      local_address = nil

      server = HTTP::Server.new do |context|
        remote_address = context.request.remote_address
        local_address = context.request.local_address
      end

      tcp_server = TCPServer.new("127.0.0.1", 0)
      server.bind tcp_server
      address1 = tcp_server.local_address

      run_server(server) do
        HTTP::Client.new(URI.parse("http://#{address1}/")) do |client|
          client.get("/")

          remote_address.should eq(client.@io.as(IPSocket).local_address)
          local_address.should eq(client.@io.as(IPSocket).remote_address)
        end
      end
    end

    it "for https server" do
      remote_address = nil
      local_address = nil

      server = HTTP::Server.new do |context|
        remote_address = context.request.remote_address
        local_address = context.request.local_address
      end

      server_context, client_context = ssl_context_pair

      socket = OpenSSL::SSL::Server.new(TCPServer.new("127.0.0.1", 0), server_context)
      server.bind socket
      ip_address1 = server.bind_tls "127.0.0.1", 0, server_context

      run_server(server) do
        HTTP::Client.new(
          uri: URI.parse("https://#{ip_address1}"),
          tls: client_context) do |client|
          client.get("/")
          remote_address.should eq(client.@io.as(OpenSSL::SSL::Socket).local_address)
          local_address.should eq(client.@io.as(OpenSSL::SSL::Socket).remote_address)
        end
      end
    end
  end

  describe "#max_request_line_size" do
    it "sets and gets size" do
      server = HTTP::Server.new { |ctx| }
      server.max_request_line_size.should eq HTTP::MAX_REQUEST_LINE_SIZE
      server.@processor.max_request_line_size.should eq HTTP::MAX_REQUEST_LINE_SIZE
      server.max_request_line_size = 20
      server.max_request_line_size.should eq 20
      server.@processor.max_request_line_size.should eq 20
    end

    it "respects size on request" do
      server = HTTP::Server.new { |ctx| }
      read = IO::Memory.new("GET /1234567 HTTP/1.1\r\n\r\n")
      write = IO::Memory.new

      io = IO::Stapled.new(read, write)
      server.@processor.process(io, io)
      write.rewind
      HTTP::Client::Response.from_io(write).status.should eq HTTP::Status::OK

      read.rewind
      write.clear

      server.max_request_line_size = 20

      io = IO::Stapled.new(read, write)
      server.@processor.process(io, io)
      write.rewind
      HTTP::Client::Response.from_io(write).status.should eq HTTP::Status::URI_TOO_LONG
    end
  end

  describe "#max_request_line_size" do
    it "sets and gets size" do
      server = HTTP::Server.new { |ctx| }
      server.max_request_line_size.should eq HTTP::MAX_REQUEST_LINE_SIZE
      server.@processor.max_request_line_size.should eq HTTP::MAX_REQUEST_LINE_SIZE
      server.max_request_line_size = 20
      server.max_request_line_size.should eq 20
      server.@processor.max_request_line_size.should eq 20
    end

    it "respects size on request" do
      server = HTTP::Server.new { |ctx| }
      read = IO::Memory.new("GET /1234567 HTTP/1.1\r\n\r\n")
      write = IO::Memory.new

      io = IO::Stapled.new(read, write)
      server.@processor.process(io, io)
      write.rewind
      HTTP::Client::Response.from_io(write).status.should eq HTTP::Status::OK

      read.rewind
      write.clear

      server.max_request_line_size = 20

      io = IO::Stapled.new(read, write)
      server.@processor.process(io, io)
      write.rewind
      HTTP::Client::Response.from_io(write).status.should eq HTTP::Status::URI_TOO_LONG
    end
  end

  describe "#max_headers_size" do
    it "sets and gets size" do
      server = HTTP::Server.new { |ctx| }
      server.max_headers_size.should eq HTTP::MAX_HEADERS_SIZE
      server.@processor.max_headers_size.should eq HTTP::MAX_HEADERS_SIZE
      server.max_headers_size = 20
      server.max_headers_size.should eq 20
      server.@processor.max_headers_size.should eq 20
    end

    it "respects size on request" do
      server = HTTP::Server.new { |ctx| }
      read = IO::Memory.new("GET /foo HTTP/1.1\r\nFoo: Bar Baz\r\n\r\n")
      write = IO::Memory.new

      io = IO::Stapled.new(read, write)
      server.@processor.process(io, io)
      write.rewind
      HTTP::Client::Response.from_io(write).status.should eq HTTP::Status::OK

      read.rewind
      write.clear

      server.max_headers_size = 10

      io = IO::Stapled.new(read, write)
      server.@processor.process(io, io)
      write.rewind
      HTTP::Client::Response.from_io(write).status.should eq HTTP::Status::REQUEST_HEADER_FIELDS_TOO_LARGE
    end
  end

  typeof(begin
    # Initialize with custom host
    server = HTTP::Server.new { |ctx| }
    server.bind_tcp "0.0.0.0", 0
    server.listen
    server.close

    server = HTTP::Server.new([
      HTTP::ErrorHandler.new,
      HTTP::LogHandler.new,
      HTTP::CompressHandler.new,
      HTTP::StaticFileHandler.new("."),
    ]
    )
    server.bind_tcp "0.0.0.0", 0
    server.listen
    server.close

    server = HTTP::Server.new([HTTP::StaticFileHandler.new(".")]) { |ctx| }
    server.bind_tcp "0.0.0.0", 0
    server.listen
    server.close

    # Initialize with default host
    server = HTTP::Server.new { |ctx| }
    server.bind_tcp 0
    server.listen
    server.close

    server = HTTP::Server.new([
      HTTP::ErrorHandler.new,
      HTTP::LogHandler.new,
      HTTP::CompressHandler.new,
      HTTP::StaticFileHandler.new("."),
    ]
    )
    server.bind_tcp 0
    server.listen
    server.close

    server = HTTP::Server.new([HTTP::StaticFileHandler.new(".")]) { |ctx| }
    server.bind_tcp 0
    server.listen
    server.close
  end)
end
