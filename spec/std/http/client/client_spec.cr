require "../spec_helper"
require "../../socket/spec_helper"
require "openssl"
require "http/client"
require "http/server"
require "log/spec"

private def test_server(host, port, read_time = 0, content_type = "text/plain", write_response = true)
  server = TCPServer.new(host, port)
  begin
    spawn do
      io = server.accept
      sleep read_time
      if write_response
        response = HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => content_type}, body: "OK")
        response.to_io(io)
        io.flush
      end
    end

    yield server
  ensure
    server.close
  end
end

private class TestClient < HTTP::Client
  def set_defaults(request)
    super
  end
end

module HTTP
  describe Client do
    typeof(Client.new("host"))
    typeof(Client.new("host", port: 8080))
    typeof(Client.new("host", tls: true))
    typeof(Client.new(URI.new))
    typeof(Client.new(URI.parse("http://www.example.com")))

    {% for method in %w(get post put head delete patch options) %}
      typeof(Client.{{method.id}} "url")
      typeof(Client.new("host").{{method.id}}("uri"))
      typeof(Client.new("host").{{method.id}}("uri", headers: Headers {"Content-Type" => "text/plain"}))
      typeof(Client.new("host").{{method.id}}("uri", body: "body"))
    {% end %}

    typeof(Client.post "url", form: {"a" => "b"})
    typeof(Client.post("url", form: {"a" => "b"}) { })
    typeof(Client.put "url", form: {"a" => "b"})
    typeof(Client.put("url", form: {"a" => "b"}) { })
    typeof(Client.new("host").basic_auth("username", "password"))
    typeof(Client.new("host").before_request { |req| })
    typeof(Client.new("host").close)
    typeof(Client.new("host").compress = true)
    typeof(Client.new("host").compress?)
    typeof(Client.get(URI.parse("http://www.example.com")))
    typeof(Client.get(URI.parse("http://www.example.com")))
    typeof(Client.get("http://www.example.com"))
    typeof(Client.post("http://www.example.com", body: IO::Memory.new))
    typeof(Client.new("host").post("/", body: IO::Memory.new))
    typeof(Client.post("http://www.example.com", body: Bytes[65]))
    typeof(Client.new("host").post("/", body: Bytes[65]))

    describe "from String" do
      it "raises when not a host" do
        ["http://www.example.com",
         "www.example.com:8080",
         "example.com/path",
         "example.com?query",
         "http://example.com:bad_port",
         "user:pass@domain"].each do |string|
          expect_raises(ArgumentError, "The string passed to create an HTTP::Client must be just a host, not #{string.inspect}") do
            Client.new(string)
          end
        end
      end
    end

    describe "from URI" do
      it "has sane defaults" do
        cl = Client.new(URI.parse("http://example.com"))
        cl.tls?.should be_nil
        cl.port.should eq(80)
      end

      {% if !flag?(:without_openssl) %}
        it "detects HTTPS" do
          cl = Client.new(URI.parse("https://example.com"))
          cl.tls?.should be_truthy
          cl.port.should eq(443)
        end

        it "keeps context" do
          ctx = OpenSSL::SSL::Context::Client.new
          cl = Client.new(URI.parse("https://example.com"), ctx)
          cl.tls.should be(ctx)
        end

        it "doesn't take context for HTTP" do
          ctx = OpenSSL::SSL::Context::Client.new
          expect_raises(ArgumentError, "TLS context given") do
            Client.new(URI.parse("http://example.com"), ctx)
          end
        end

        it "allows for specified ports" do
          cl = Client.new(URI.parse("https://example.com:9999"))
          cl.tls?.should be_truthy
          cl.port.should eq(9999)
        end
      {% else %}
        it "raises when trying to activate TLS" do
          expect_raises(Exception, "TLS is disabled") do
            Client.new "example.org", 443, tls: true
          end
        end
      {% end %}

      it "raises error if not http schema" do
        expect_raises(ArgumentError, "Unsupported scheme: ssh") do
          Client.new(URI.parse("ssh://example.com"))
        end
      end

      it "raises error if URI is missing host" do
        expect_raises(ArgumentError, "must have host") do
          Client.new(URI.parse("http:/"))
        end
      end

      it "yields to a block" do
        Client.new(URI.parse("http://example.com")) do |client|
          typeof(client)
        end
      end
    end

    context "from a host" do
      it "yields to a block" do
        Client.new("example.com") do |client|
          typeof(client)
        end
      end
    end

    pending_ipv6 "sends the host header ipv6 with brackets" do
      server = HTTP::Server.new do |context|
        context.response.print context.request.headers["Host"]
      end
      address = server.bind_unused_port "::1"

      run_server(server) do
        HTTP::Client.get("http://[::1]:#{address.port}/").body.should eq("[::1]:#{address.port}")
      end
    end

    it "sends a 'connection: close' header on one-shot request" do
      server = HTTP::Server.new do |context|
        context.response.print context.request.headers["connection"]
      end
      address = server.bind_unused_port "127.0.0.1"

      run_server(server) do
        HTTP::Client.get("http://127.0.0.1:#{address.port}/").body.should eq("close")
      end
    end

    it "sends a 'connection: close' header on one-shot request with block" do
      server = HTTP::Server.new do |context|
        context.response.print context.request.headers["connection"]
      end
      address = server.bind_unused_port "127.0.0.1"

      run_server(server) do
        HTTP::Client.get("http://127.0.0.1:#{address.port}/") do |response|
          response.body_io.gets_to_end
        end.should eq("close")
      end
    end

    it "doesn't read the body if request was HEAD" do
      resp_get = test_server("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        break client.get("/")
      end

      test_server("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        resp_head = client.head("/")
        resp_head.headers.should eq(resp_get.headers)
        resp_head.body.should eq("")
      end
    end

    it "raises if URI is missing scheme" do
      expect_raises(ArgumentError, "Missing scheme") do
        HTTP::Client.get URI.parse("www.example.com")
      end
    end

    it "raises if URI is missing host" do
      expect_raises(ArgumentError, "must have host") do
        HTTP::Client.get URI.parse("http://")
      end
    end

    it "tests read_timeout" do
      test_server("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        client.read_timeout = 1.second
        client.get("/")
      end

      # Here we don't want to write a response on the server side because
      # it doesn't make sense to try to write because the client will already
      # timeout on read. Writing a response could lead on an exception in
      # the server if the socket is closed.
      test_server("localhost", 0, 0.5, write_response: false) do |server|
        client = Client.new("localhost", server.local_address.port)
        expect_raises(IO::TimeoutError, "Read timed out") do
          client.read_timeout = 0.001
          client.get("/?sleep=1")
        end
      end
    end

    {% unless flag?(:darwin) %}
      # TODO the following spec is failing on Nix Darwin CI when executed
      #      together with some other tests. If run alone it succeeds.
      #      The exhibit failure is a Failed to raise an exception: END_OF_STACK.
      it "tests write_timeout" do
        # Here we don't want to write a response on the server side because
        # it doesn't make sense to try to write because the client will already
        # timeout on read. Writing a response could lead on an exception in
        # the server if the socket is closed.
        test_server("localhost", 0, 0, write_response: false) do |server|
          client = Client.new("localhost", server.local_address.port)
          expect_raises(IO::TimeoutError, "Write timed out") do
            client.write_timeout = 0.001
            client.post("/", body: "a" * 5_000_000)
          end
        end
      end
    {% end %}

    it "tests connect_timeout" do
      test_server("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        client.connect_timeout = 0.5
        client.get("/")
      end
    end

    it "tests empty Content-Type" do
      test_server("localhost", 0, content_type: "") do |server|
        client = Client.new("localhost", server.local_address.port)
        client.get("/")
      end
    end

    describe "#set_defaults" do
      it "sets default Host header" do
        client = TestClient.new "www.example.com"
        request = HTTP::Request.new("GET", "/")
        client.set_defaults(request)
        request.host.should eq "www.example.com"

        request = HTTP::Request.new("GET", "/", HTTP::Headers{"Host" => "other.example.com"})
        client.set_defaults(request)
        request.host.should eq "other.example.com"
      end
    end

    it "works with IO" do
      io_response = IO::Memory.new <<-RESPONSE.gsub('\n', "\r\n")
      HTTP/1.1 200 OK
      Content-Type: text/plain
      Content-Length: 3

      Hi!
      RESPONSE
      io_request = IO::Memory.new
      io = IO::Stapled.new(io_response, io_request)
      client = Client.new(io)
      response = client.get("/")
      response.body.should eq("Hi!")

      io_request.rewind
      request = HTTP::Request.from_io(io_request).as(HTTP::Request)
      request.host.should eq("")
    end

    it "can specify host and port when initialized with IO" do
      client = Client.new(IO::Memory.new, "host", 1234)
      client.host.should eq("host")
      client.port.should eq(1234)
    end

    it "cannot reconnect when initialized with IO" do
      io = IO::Memory.new
      client = Client.new(io)
      client.close
      io.closed?.should be_true
      expect_raises(Exception, "This HTTP::Client cannot be reconnected") do
        client.get("/")
      end
    end

    describe "logging" do
      it "emit logs" do
        test_server("localhost", 0, content_type: "") do |server|
          client = Client.new("localhost", server.local_address.port)
          Log.capture("http.client") do |logs|
            client.get("/")

            logs.check(:debug, "Performing request")
            logs.entry.data[:method].should eq("GET")
            logs.entry.data[:host].should eq("localhost")
            logs.entry.data[:port].should eq(server.local_address.port)
            logs.entry.data[:resource].should eq("/")
          end
        end
      end

      it "emit logs with block" do
        test_server("localhost", 0, content_type: "") do |server|
          Client.new("localhost", server.local_address.port) do |client|
            Log.capture("http.client") do |logs|
              client.get("/") do |response|
                logs.check(:debug, "Performing request")
                logs.entry.data[:method].should eq("GET")
                logs.entry.data[:host].should eq("localhost")
                logs.entry.data[:port].should eq(server.local_address.port)
                logs.entry.data[:resource].should eq("/")
              end
            end
          end
        end
      end
    end
  end
end
