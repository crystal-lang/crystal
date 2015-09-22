require "spec"
require "http/request"

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

    describe "#uri" do
      it "returns parsed URI" do
        request = Request.from_io(StringIO.new("GET /api/v3/some/resource?filter=hello&world=test#iamafragment HTTP/1.1\r\n\r\n")).not_nil!
        uri = request.uri

        uri.path.should eq("/api/v3/some/resource")
        uri.query.should eq("filter=hello&world=test")
        uri.fragment.should eq("iamafragment")
      end
    end
  end
end
