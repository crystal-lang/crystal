require "spec"
require "openssl"
require "http/client"
require "http/server"

private class TestServer < TCPServer
  def self.open(host, port, read_time = 0)
    server = new(host, port)
    begin
      spawn do
        io = server.accept
        sleep read_time
        response = HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type" => "text/plain"}, body: "OK")
        response.to_io(io)
        io.flush
      end

      yield server
    ensure
      server.close
    end
  end
end

module HTTP
  describe Client do
    typeof(Client.new("host", port: 8080))
    typeof(Client.new("host", 80, tls: true))
    typeof(Client.new(URI.new))
    typeof(Client.new(URI.parse("http://www.example.com")))

    {% for method in %w(get post put head delete patch options) %}
      typeof(Client.{{method.id}} "url")
      typeof(Client.new.{{method.id}}("uri"))
      typeof(Client.new.{{method.id}}("uri", headers: Headers {"Content-Type" => "text/plain"}))
      typeof(Client.new.{{method.id}}("uri", body: "body"))
    {% end %}

    typeof(Client.post "url", form: {"a" => "b"})
    typeof(Client.post("url", form: {"a" => "b"}) { })
    typeof(Client.put "url", form: {"a" => "b"})
    typeof(Client.put("url", form: {"a" => "b"}) { })
    typeof(Client.new.basic_auth("username", "password"))
    typeof(Client.new.before_request { |req| })
    typeof(Client.new.close)
    typeof(Client.new.compress = true)
    typeof(Client.new.compress?)
    typeof(Client.get(URI.parse("http://www.example.com")))
    typeof(Client.get(URI.parse("http://www.example.com")))
    typeof(Client.get("http://www.example.com"))
    typeof(Client.post("http://www.example.com", body: IO::Memory.new))
    typeof(Client.new.post("/", body: IO::Memory.new))
    typeof(Client.post("http://www.example.com", body: Bytes[65]))
    typeof(Client.new.post("/", body: Bytes[65]))

    describe "from URI" do
      it "has sane defaults" do
        cl = Client.new(URI.parse("http://example.com"))
        cl.tls.should be_a(OpenSSL::SSL::Context::Client)
        cl.base_uri.port.should eq(80)
      end

      {% if !flag?(:without_openssl) %}
        it "detects HTTPS" do
          cl = Client.new(URI.parse("https://example.com"))
          cl.tls.should be_truthy
          cl.base_uri.port.should eq(443)
        end

        it "keeps context" do
          ctx = OpenSSL::SSL::Context::Client.new
          cl = Client.new(URI.parse("https://example.com"), ctx)
          cl.tls.should be(ctx)
        end

        it "allows for specified ports" do
          cl = Client.new(URI.parse("https://example.com:9999"))
          cl.tls.should be_truthy
          cl.base_uri.port.should eq(9999)
        end
      {% else %}
        it "raises when trying to activate TLS" do
          expect_raises(Exception, "TLS is disabled") do
            Client.new "example.org", 443, tls: true
          end
        end
      {% end %}

      it "raises error if URI is missing host" do
        expect_raises(ArgumentError, "must have host") do
          Client.new(URI.parse("http:/"))
        end
      end

      it "yields to a block" do
        Client.open(URI.parse("http://example.com")) do |client|
          typeof(client)
        end
      end
    end

    context "from a host" do
      it "yields to a block" do
        Client.open("example.com", 80) do |client|
          typeof(client)
        end
      end
    end

    it "doesn't read the body if request was HEAD" do
      resp_get = TestServer.open("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        break client.get("/")
      end

      TestServer.open("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        resp_head = client.head("/")
        resp_head.headers.should eq(resp_get.headers)
        resp_head.body.should eq("")
      end
    end

    it "raises if URI is missing scheme" do
      expect_raises(ArgumentError, "Missing scheme") do
        HTTP::Client.get URI.parse("//www.example.com")
      end
    end

    it "raises if URI is missing host" do
      expect_raises(ArgumentError, "Missing host") do
        HTTP::Client.get URI.parse("http://")
      end
    end

    it "tests read_timeout" do
      TestServer.open("localhost", 0, 0) do |server|
        transport = Client::Transport::TCPTransport.new("localhost", server.local_address.port)
        transport.read_timeout = 1.seconds
        client = Client.new(transport, base_uri: URI.new("http", "localhost", server.local_address.port))
        client.get("/")
      end

      TestServer.open("localhost", 0, 0.5) do |server|
        transport = Client::Transport::TCPTransport.new("localhost", server.local_address.port)
        transport.read_timeout = 0.001.seconds

        client = Client.new(transport, base_uri: URI.new("http", "localhost", server.local_address.port))
        expect_raises(IO::Timeout, "Read timed out") do
          client.get("/?sleep=1")
        end
      end
    end

    it "tests connect_timeout" do
      TestServer.open("localhost", 0, 0) do |server|
        transport = Client::Transport::TCPTransport.new("localhost", server.local_address.port)
        transport.connect_timeout = 0.5.seconds

        client = Client.new(transport, base_uri: URI.new("http", "localhost", server.local_address.port))
        client.get("/")
      end
    end
  end

  it "raises when host is empty" do
    client = Client.new

    expect_raises(Exception, "Missing host") do
      client.get("/foo/bar")
    end
  end

  describe "transport" do
    it "#get uses transport" do
      io = IO::Memory.new

      transport = Client::Transport.new do |uri, request|
        request.host.should eq "example.com"
        request.resource.should eq "/foo/bar"
        request.method.should eq "GET"
        uri.should eq URI.parse("http://example.com/foo/bar")

        io
      end

      expect_raises(Exception, "Unexpected end of http response") do
        Client.new(transport).get("http://example.com/foo/bar")
      end

      io.to_s.lines.first.should eq "GET /foo/bar HTTP/1.1"
    end

    it ".get uses transport" do
      io = IO::Memory.new

      transport = Client::Transport.new do |uri, request|
        request.host.should eq "example.com"
        request.resource.should eq "/foo/bar"
        request.method.should eq "GET"
        uri.should eq URI.parse("http://example.com/foo/bar")

        io
      end

      expect_raises(Exception, "Unexpected end of http response") do
        Client.get("http://example.com/foo/bar", transport: transport)
      end

      io.to_s.lines.first.should eq "GET /foo/bar HTTP/1.1"
    end

    it "uses Unix pipe transport" do
      UNIXServer.open("/tmp/http-client-transport-socket.sock") do |server|
        spawn do
          client = server.accept
          request = HTTP::Request.from_io(client)

          request.should be_a(HTTP::Request)
          request = request.as(HTTP::Request)
          request.host.should eq "example.com"
          request.path.should eq "/foo/bar"

          HTTP::Server::Response.new(client).close
        end
        Fiber.yield

        transport = Client::Transport::UNIX.new("/tmp/http-client-transport-socket.sock")
        Client.get("http://example.com/foo/bar", transport: transport)
        transport.socket.close
      end
    ensure
      File.delete("/tmp/http-client-transport-socket.sock") if File.exists?("/tmp/http-client-transport-socket.sock")
    end
  end
end
