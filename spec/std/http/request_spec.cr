require "spec"
require "http/request"
require "socket"

module HTTP
  describe Request do
    it "serialize GET" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      request = Request.new "GET", "/", headers

      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")
    end

    it "serialize GET (with query params)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      request = Request.new "GET", "/greet?q=hello&name=world", headers

      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("GET /greet?q=hello&name=world HTTP/1.1\r\nHost: host.example.org\r\n\r\n")
    end

    it "serialize GET (with cookie)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      request = Request.new "GET", "/", headers
      request.cookies << Cookie.new("foo", "bar")

      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar; path=/\r\n\r\n")
    end

    it "serialize GET (with cookies, from headers)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      headers["Cookie"] = "foo=bar; path=/"

      request = Request.new "GET", "/", headers

      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar; path=/\r\n\r\n")

      request.cookies["foo"].value.should eq "bar" # Force lazy initialization

      io.clear
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar; path=/\r\n\r\n")

      request.cookies["foo"] = "baz"
      request.cookies["quux"] = "baz"

      io.clear
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=baz; path=/\r\nCookie: quux=baz; path=/\r\n\r\n")
    end

    it "serialize POST (with body)" do
      request = Request.new "POST", "/", body: "thisisthebody"
      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")
    end

    it "parses GET" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "parses GET with query params" do
      request = Request.from_io(StringIO.new("GET /greet?q=hello&name=world HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
      request.method.should eq("GET")
      request.path.should eq("/greet")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "parses GET without \\r" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\nHost: host.example.org\n\n")).not_nil!
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "parses empty header" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nReferer:\r\n\r\n")).not_nil!
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.example.org", "Referer" => ""})
    end

    it "parses GET with cookie" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: a=b\r\n\r\n")).not_nil!
      request.method.should eq("GET")
      request.path.should eq("/")
      request.cookies["a"].value.should eq("b")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "headers are case insensitive" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
      headers = request.headers.not_nil!
      headers["HOST"].should eq("host.example.org")
      headers["host"].should eq("host.example.org")
      headers["Host"].should eq("host.example.org")
    end

    it "parses POST (with body)" do
      request = Request.from_io(StringIO.new("POST /foo HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")).not_nil!
      request.method.should eq("POST")
      request.path.should eq("/foo")
      request.headers.should eq({"Content-Length" => "13"})
      request.body.should eq("thisisthebody")
    end

    describe "keep-alive" do
      it "is false by default in HTTP/1.0" do
        request = Request.new "GET", "/", version: "HTTP/1.0"
        request.keep_alive?.should be_false
      end

      it "is true in HTTP/1.0 if `Connection: keep-alive` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "keep-alive"
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.0"
        request.keep_alive?.should be_true
      end

      it "is true by default in HTTP/1.1" do
        request = Request.new "GET", "/", version: "HTTP/1.1"
        request.keep_alive?.should be_true
      end

      it "is false in HTTP/1.1 if `Connection: close` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "close"
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.1"
        request.keep_alive?.should be_false
      end
    end

    describe "#path" do
      it "returns parsed path" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.path.should eq("/api/v3/some/resource")
      end
    end

    describe "#path=" do
      it "sets path" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.path = "/api/v2/greet"
        request.path.should eq("/api/v2/greet")
      end

      it "updates @resource" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.path = "/api/v2/greet"
        request.resource.should eq("/api/v2/greet?filter=hello&world=test")
      end

      it "updates serialized form" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.path = "/api/v2/greet"

        io = StringIO.new
        request.to_io(io)
        io.to_s.should eq("GET /api/v2/greet?filter=hello&world=test HTTP/1.1\r\n\r\n")
      end
    end

    describe "#query" do
      it "returns request's query" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.query.should eq("filter=hello&world=test")
      end
    end

    describe "#query=" do
      it "sets query" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.query = "q=isearchforsomething&locale=de"
        request.query.should eq("q=isearchforsomething&locale=de")
      end

      it "updates @resource" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.query = "q=isearchforsomething&locale=de"
        request.resource.should eq("/api/v3/some/resource?q=isearchforsomething&locale=de")
      end

      it "updates serialized form" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).not_nil!
        request.query = "q=isearchforsomething&locale=de"

        io = StringIO.new
        request.to_io(io)
        io.to_s.should eq("GET /api/v3/some/resource?q=isearchforsomething&locale=de HTTP/1.1\r\n\r\n")
      end
    end

    describe "#peer_addr=" do
      it "sets the peer_addr" do
        request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
        addr = Socket::Addr.new("AF_INET", "12345", "127.0.0.1")
        request.peer_addr = addr
        request.peer_addr.should eq addr
      end
    end

    describe "#peer_addr" do
      it "returns the peer_addr" do
        request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
        addr = Socket::Addr.new("AF_INET", "12345", "127.0.0.1")
        request.peer_addr = addr
        request.peer_addr.should eq addr
      end

      it "raises if peer_addr is nil" do
        request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!

        expect_raises do
          request.peer_addr
        end
      end
    end

    describe "#remote_ip" do
      context "trusting headers" do
        it "returns the remote ip from the Client-Ip" do
          request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nClient-Ip: 8.8.8.8\r\n\r\n")).not_nil!
          addr    = Socket::Addr.new("AF_INET", "12345", "127.0.0.1")
          request.peer_addr = addr

          request.remote_ip.should eq "8.8.8.8"
        end

        it "returns the remote ip from the X-Forwarded-For header" do
          request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nX-Forwarded-For: 4.4.4.4, 10.0.0.1\r\n\r\n")).not_nil!
          addr    = Socket::Addr.new("AF_INET", "12345", "127.0.0.1")
          request.peer_addr = addr

          request.remote_ip.should eq "4.4.4.4"
        end

        it "returns the peer addr if headers are not set" do
          request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
          addr    = Socket::Addr.new("AF_INET", "12345", "127.0.0.1")
          request.peer_addr = addr

          request.remote_ip.should eq "127.0.0.1"
        end
      end

      context "without trusting headers" do
        it "returns the peer_addr ip address" do
          request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).not_nil!
          addr = Socket::Addr.new("AF_INET", "12345", "127.0.0.1")
          request.peer_addr = addr

          request.remote_ip(false).should eq "127.0.0.1"
        end
      end
    end
  end
end
