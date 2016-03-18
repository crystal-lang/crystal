require "spec"
require "http/client"
require "http/server"

class TestServer < TCPServer
  def self.open(host, port, read_time = 0)
    server = new(host, port)
    begin
      spawn do
        io = server.accept
        sleep read_time
        response = HTTP::Client::Response.new(200, headers: HTTP::Headers{"Content-Type": "text/plain"}, body: "OK")
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
    typeof(Client.new("host"))
    typeof(Client.new("host", port: 8080))
    typeof(Client.new("host", ssl: true))
    typeof(Client.new(URI.new))
    typeof(Client.new(URI.parse("http://www.example.com")))

    {% for method in %w(get post put head delete patch) %}
      typeof(Client.{{method.id}} "url")
      typeof(Client.new("host").{{method.id}}("uri"))
      typeof(Client.new("host").{{method.id}}("uri", headers: Headers {"Content-Type": "text/plain"}))
      typeof(Client.new("host").{{method.id}}("uri", body: "body"))
    {% end %}

    typeof(Client.post_form "url", {"a": "b"})
    typeof(Client.new("host").basic_auth("username", "password"))
    typeof(Client.new("host").before_request { |req| })
    typeof(Client.new("host").close)
    typeof(Client.new("host").compress = true)
    typeof(Client.new("host").compress?)
    typeof(Client.get(URI.parse("http://www.example.com")))
    typeof(Client.get(URI.parse("http://www.example.com")))
    typeof(Client.get("http://www.example.com"))

    describe "from URI" do
      it "has sane defaults" do
        cl = Client.new(URI.parse("http://demo.com"))
        cl.ssl?.should be_false
        cl.port.should eq(80)
      end

      it "detects ssl" do
        cl = Client.new(URI.parse("https://demo.com"))
        cl.ssl?.should be_true
        cl.port.should eq(443)
      end

      it "allows for specified ports" do
        cl = Client.new(URI.parse("https://demo.com:9999"))
        cl.ssl?.should be_true
        cl.port.should eq(9999)
      end

      it "raises error if not http schema" do
        expect_raises(ArgumentError, "Unsupported scheme: ssh") do
          Client.new(URI.parse("ssh://demo.com"))
        end
      end

      it "raises error if URI is missing host" do
        expect_raises(ArgumentError, "must have host") do
          Client.new(URI.parse("http:/"))
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
      expect_raises(ArgumentError, "missing scheme") do
        HTTP::Client.get URI.parse("www.example.com")
      end
    end

    it "raises if URI is missing host" do
      expect_raises(ArgumentError, "must have host") do
        HTTP::Client.get URI.parse("http://")
      end
    end

    it "tests read_timeout" do
      TestServer.open("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        client.read_timeout = 1.second
        client.get("/")
      end

      TestServer.open("localhost", 0, 0.5) do |server|
        client = Client.new("localhost", server.local_address.port)
        expect_raises(IO::Timeout, "read timed out") do
          client.read_timeout = 0.001
          client.get("/?sleep=1")
        end
      end
    end

    it "tests connect_timeout" do
      TestServer.open("localhost", 0, 0) do |server|
        client = Client.new("localhost", server.local_address.port)
        client.connect_timeout = 0.5
        client.get("/")
      end
    end
  end
end
