require "../../spec_helper"
require "http/server"
require "http/client/response"
require "../../../support/ssl"

private def wait_for(timeout = 5.seconds)
  now = Time.monotonic

  until yield
    Fiber.yield

    if (Time.monotonic - now) > timeout
      raise "server failed to start within 5 seconds"
    end
  end
end

private class RaiseErrno < IO
  def initialize(@value : Int32)
  end

  def read(slice : Bytes)
    Errno.value = @value
    raise Errno.new "..."
  end

  def write(slice : Bytes) : Nil
    raise "not implemented"
  end
end

private class ReverseResponseOutput < IO
  @output : IO

  def initialize(@output : IO)
  end

  def write(slice : Bytes)
    slice.reverse_each do |byte|
      @output.write_byte(byte)
    end
  end

  def read(slice : Bytes)
    raise "Not implemented"
  end

  def close
    @output.close
  end

  def flush
    @output.flush
  end
end

# TODO: replace with `HTTP::Client` once it supports connecting to Unix socket (#2735)
private def unix_request(path)
  UNIXSocket.open(path) do |io|
    request = HTTP::Request.new("GET", "/", HTTP::Headers{"X-Unix-Socket" => path})
    request.to_io(io)

    HTTP::Client::Response.from_io(io).body
  end
end

private def unused_port
  TCPServer.open(0) do |server|
    server.local_address.port
  end
end

private class SilentErrorHTTPServer < HTTP::Server
  private def handle_exception(e)
  end
end

module HTTP
  class Server
    describe Response do
      it "closes" do
        io = IO::Memory.new
        response = Response.new(io)
        response.close
        response.closed?.should be_true
        io.closed?.should be_false
        expect_raises(IO::Error, "Closed stream") { response << "foo" }
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      end

      it "prints less then buffer's size" do
        io = IO::Memory.new
        response = Response.new(io)
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "prints less then buffer's size to output" do
        io = IO::Memory.new
        response = Response.new(io)
        response.output.print("Hello")
        response.output.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "prints more then buffer's size" do
        io = IO::Memory.new
        response = Response.new(io)
        str = "1234567890"
        1000.times do
          response.print(str)
        end
        response.close
        first_chunk = str * 819
        second_chunk = str * 181
        io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1ffe\r\n#{first_chunk}\r\n712\r\n#{second_chunk}\r\n0\r\n\r\n")
      end

      it "prints with content length" do
        io = IO::Memory.new
        response = Response.new(io)
        response.headers["Content-Length"] = "10"
        response.print("1234")
        response.print("567890")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n1234567890")
      end

      it "prints with content length (method)" do
        io = IO::Memory.new
        response = Response.new(io)
        response.content_length = 10
        response.print("1234")
        response.print("567890")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n1234567890")
      end

      it "adds header" do
        io = IO::Memory.new
        response = Response.new(io)
        response.headers["Content-Type"] = "text/plain"
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "sets content type" do
        io = IO::Memory.new
        response = Response.new(io)
        response.content_type = "text/plain"
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
      end

      it "changes status and others" do
        io = IO::Memory.new
        response = Response.new(io)
        response.status_code = 404
        response.version = "HTTP/1.0"
        response.close
        io.to_s.should eq("HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n")
      end

      it "flushes" do
        io = IO::Memory.new
        response = Response.new(io)
        response.print("Hello")
        response.flush
        io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n0\r\n\r\n")
      end

      it "wraps output" do
        io = IO::Memory.new
        response = Response.new(io)
        response.output = ReverseResponseOutput.new(response.output)
        response.print("1234")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\n4321")
      end

      it "writes and flushes with HTTP 1.0" do
        io = IO::Memory.new
        response = Response.new(io, "HTTP/1.0")
        response.print("1234")
        response.flush
        io.to_s.should eq("HTTP/1.0 200 OK\r\n\r\n1234")
      end

      it "resets and clears headers and cookies" do
        io = IO::Memory.new
        response = Response.new(io)
        response.headers["Foo"] = "Bar"
        response.cookies["Bar"] = "Foo"
        response.reset
        response.headers.empty?.should be_true
        response.cookies.empty?.should be_true
      end

      it "writes cookie headers" do
        io = IO::Memory.new
        response = Response.new(io)
        response.cookies["Bar"] = "Foo"
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nSet-Cookie: Bar=Foo; path=/\r\n\r\n")

        io = IO::Memory.new
        response = Response.new(io)
        response.cookies["Bar"] = "Foo"
        response.print("Hello")
        response.close
        io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nSet-Cookie: Bar=Foo; path=/\r\n\r\nHello")
      end

      it "responds with an error" do
        io = IO::Memory.new
        response = Response.new(io)
        response.content_type = "text/html"
        response.respond_with_error
        io.to_s.should eq("HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n1a\r\n500 Internal Server Error\n\r\n")

        io = IO::Memory.new
        response = Response.new(io)
        response.respond_with_error("Bad Request", 400)
        io.to_s.should eq("HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n10\r\n400 Bad Request\n\r\n")
      end
    end
  end

  describe HTTP::Server do
    it "binds to unused port" do
      server = Server.new { |ctx| }
      address = server.bind_unused_port
      address.port.should_not eq(0)

      server = Server.new { |ctx| }
      port = server.bind_tcp(0).port
      port.should_not eq(0)
    end

    it "doesn't raise on accept after close #2692" do
      server = Server.new { }
      server.bind_unused_port

      spawn do
        server.close
        sleep 0.001
      end

      server.listen
    end

    it "reuses the TCP port (SO_REUSEPORT)" do
      s1 = Server.new { |ctx| }
      address = s1.bind_unused_port(reuse_port: true)

      s2 = Server.new { |ctx| }
      s2.bind_tcp(address.port, reuse_port: true)

      s1.close
      s2.close
    end

    it "binds to different ports" do
      server = Server.new do |context|
        context.response.print "Test Server (#{context.request.headers["Host"]?})"
      end

      tcp_server = TCPServer.new("127.0.0.1", 0)
      server.bind tcp_server
      address1 = tcp_server.local_address

      address2 = server.bind_unused_port

      address1.should_not eq address2

      spawn { server.listen }

      HTTP::Client.get("http://#{address2}/").body.should eq "Test Server (#{address2})"
      HTTP::Client.get("http://#{address1}/").body.should eq "Test Server (#{address1})"
      HTTP::Client.get("http://#{address1}/").body.should eq "Test Server (#{address1})"
    end

    it "handles Expect: 100-continue correctly when body is read" do
      server = Server.new do |context|
        context.response << context.request.body.not_nil!.gets_to_end
      end

      address = server.bind_unused_port
      spawn server.listen

      wait_for { server.listening? }

      TCPSocket.open(address.address, address.port) do |socket|
        socket << requestize(<<-REQUEST
          POST / HTTP/1.1
          Expect: 100-continue
          Content-Length: 5

          REQUEST
        )
        socket << "\r\n"
        socket.flush

        response = Client::Response.from_io(socket)
        response.status_code.should eq(100)

        socket << "hello"
        socket.flush

        response = Client::Response.from_io(socket)
        response.status_code.should eq(200)
        response.body.should eq("hello")
      end
    end

    it "handles Expect: 100-continue correctly when body isn't read" do
      server = Server.new do |context|
        context.response.respond_with_error("I don't want your body", 400)
      end

      address = server.bind_unused_port
      spawn server.listen

      wait_for { server.listening? }

      TCPSocket.open(address.address, address.port) do |socket|
        socket << requestize(<<-REQUEST
          POST / HTTP/1.1
          Expect: 100-continue
          Content-Length: 5

          REQUEST
        )
        socket << "\r\n"
        socket.flush

        response = Client::Response.from_io(socket)
        response.status_code.should eq(400)
        response.body.should eq("400 I don't want your body\n")
      end
    end

    it "lists addresses" do
      server = Server.new { }

      tcp_server = TCPServer.new("127.0.0.1", 0)
      addresses = [server.bind_unused_port, server.bind_unused_port, tcp_server.local_address]
      server.bind tcp_server

      server.addresses.should eq addresses
    end

    describe "#bind" do
      it "fails after listen" do
        server = Server.new { }
        server.bind_unused_port
        spawn { server.listen }
        wait_for { server.listening? }
        expect_raises(Exception, "Can't add socket to running server") do
          server.bind_unused_port
        end
        server.close
      end

      it "fails after close" do
        server = Server.new { }
        server.bind_unused_port
        spawn { server.listen }
        wait_for { server.listening? }
        server.close
        expect_raises(Exception, "Can't add socket to closed server") do
          server.bind_unused_port
        end
        server.close unless server.closed?
      end

      describe "with URI" do
        it "accepts URI" do
          server = Server.new { }

          begin
            port = unused_port
            address = server.bind URI.parse("tcp://127.0.0.1:#{port}")
            address.should eq Socket::IPAddress.new("127.0.0.1", port)
          ensure
            server.close
          end
        end

        it "accepts String" do
          server = Server.new { }

          begin
            port = unused_port
            address = server.bind "tcp://127.0.0.1:#{port}"
            address.should eq Socket::IPAddress.new("127.0.0.1", port)
          ensure
            server.close
          end
        end

        it "parses TCP" do
          server = Server.new { }

          begin
            port = unused_port
            address = server.bind "tcp://127.0.0.1:#{port}"
            address.should eq Socket::IPAddress.new("127.0.0.1", port)
          ensure
            server.close
          end
        end

        it "parses SSL" do
          server = Server.new { }

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
          server = Server.new { }

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
          server = Server.new { }

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
        server = Server.new do |context|
          context.response.puts "Test Server (#{context.request.headers["Host"]?})"
          context.response.close
        end

        server_context, client_context = ssl_context_pair

        socket = OpenSSL::SSL::Server.new(TCPServer.new("127.0.0.1", 0), server_context)
        server.bind socket
        ip_address1 = server.bind_tls "127.0.0.1", 0, server_context
        ip_address2 = socket.local_address

        spawn server.listen

        HTTP::Client.get("https://#{ip_address1}", tls: client_context).body.should eq "Test Server (#{ip_address1})\n"
        HTTP::Client.get("https://#{ip_address2}", tls: client_context).body.should eq "Test Server (#{ip_address2})\n"

        server.close
      end
    end

    describe "#listen" do
      it "fails after listen" do
        server = Server.new { }
        server.bind_unused_port
        spawn { server.listen }
        wait_for { server.listening? }
        expect_raises(Exception, "Can't start running server") do
          server.listen
        end
        server.close
      end

      it "fails after close" do
        server = Server.new { }
        server.bind_unused_port
        spawn { server.listen }
        wait_for { server.listening? }
        server.close
        server.listening?.should be_false
        expect_raises(Exception, "Can't re-start closed server") do
          server.listen
        end
      end
    end

    {% if flag?(:unix) %}
      describe "#bind_unix" do
        it "binds to different unix sockets" do
          path1 = File.tempname
          path2 = File.tempname

          begin
            server = Server.new do |context|
              # TODO: Replace custom header with local_address (#5784)
              context.response.print "Test Server (#{context.request.headers["X-Unix-Socket"]?})"
              context.response.close
            end

            socket1 = UNIXServer.new(path1)
            server.bind socket1
            socket2 = server.bind_unix path2

            spawn server.listen
            wait_for { server.listening? }

            unix_request(path1).should eq "Test Server (#{path1})"
            unix_request(path2).should eq "Test Server (#{path2})"

            server.close

            File.exists?(path1).should be_false
            File.exists?(path2).should be_false
          ensure
            File.delete(path1) if File.exists?(path1)
            File.delete(path2) if File.exists?(path2)
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

      server_done = false
      spawn do
        server.listen
      ensure
        server_done = true
      end

      3.times do
        # Perform multiple wrong calls together and check
        # that the server is still able to respond.
        3.times do
          empty_context = OpenSSL::SSL::Context::Client.new
          socket = TCPSocket.new(address.address, address.port)
          expect_raises(OpenSSL::SSL::Error) do
            OpenSSL::SSL::Socket::Client.new(socket, empty_context)
          end
        end
        HTTP::Client.get("https://#{address}/", tls: client_context).body.should eq "ok"
      end

      server_done.should be_false
    end

    describe "#close" do
      it "closes gracefully" do
        server = Server.new do |context|
          context.response.flush
          context.response.puts "foo"
          context.response.flush

          context.response.puts "bar"
        end

        address = server.bind_unused_port
        spawn server.listen

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

  describe HTTP::Server::RequestProcessor do
    it "works" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.print "Hello world"
      end

      input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 11

        Hello world
        RESPONSE
      ))
    end

    it "skips body between requests" do
      processor = HTTP::Server::RequestProcessor.new do |context|
        context.response.content_type = "text/plain"
        context.response.puts "Hello world\r"
      end

      input = IO::Memory.new(requestize(<<-REQUEST
        POST / HTTP/1.1
        Content-Length: 7

        hello
        POST / HTTP/1.1
        Content-Length: 7

        hello
        REQUEST
      ))
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind
      output.gets_to_end.should eq(requestize(<<-RESPONSE
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 13

        Hello world
        HTTP/1.1 200 OK
        Connection: keep-alive
        Content-Type: text/plain
        Content-Length: 13

        Hello world

        RESPONSE
      ))
    end

    it "handles Errno" do
      processor = HTTP::Server::RequestProcessor.new { }
      input = RaiseErrno.new(Errno::ECONNRESET)
      output = IO::Memory.new
      processor.process(input, output)
      output.rewind.gets_to_end.empty?.should be_true
    end

    it "catches raised error on handler" do
      processor = HTTP::Server::RequestProcessor.new { raise "OH NO" }
      input = IO::Memory.new("GET / HTTP/1.1\r\n\r\n")
      output = IO::Memory.new
      error = IO::Memory.new
      processor.process(input, output, error)
      output.rewind.gets_to_end.should match(/Internal Server Error/)
    end
  end

  typeof(begin
    # Initialize with custom host
    server = Server.new { |ctx| }
    server.bind_tcp "0.0.0.0", 0
    server.listen
    server.close

    server = Server.new([
      ErrorHandler.new,
      LogHandler.new,
      CompressHandler.new,
      StaticFileHandler.new("."),
    ]
    )
    server.bind_tcp "0.0.0.0", 0
    server.listen
    server.close

    server = Server.new([StaticFileHandler.new(".")]) { |ctx| }
    server.bind_tcp "0.0.0.0", 0
    server.listen
    server.close

    # Initialize with default host
    server = Server.new { |ctx| }
    server.bind_tcp 0
    server.listen
    server.close

    server = Server.new([
      ErrorHandler.new,
      LogHandler.new,
      CompressHandler.new,
      StaticFileHandler.new("."),
    ]
    )
    server.bind_tcp 0
    server.listen
    server.close

    server = Server.new([StaticFileHandler.new(".")]) { |ctx| }
    server.bind_tcp 0
    server.listen
    server.close
  end)
end

private def requestize(string)
  string.gsub('\n', "\r\n")
end
