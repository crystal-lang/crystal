require "spec"
require "http/request"

module HTTP
  describe Request do
    it "serialize GET" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      orignal_headers = headers.dup
      request = Request.new "GET", "/", headers

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")
      headers.should eq(orignal_headers)
    end

    it "serialize GET (with query params)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      orignal_headers = headers.dup
      request = Request.new "GET", "/greet?q=hello&name=world", headers

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET /greet?q=hello&name=world HTTP/1.1\r\nHost: host.example.org\r\n\r\n")
      headers.should eq(orignal_headers)
    end

    it "serialize GET (with cookie)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      orignal_headers = headers.dup
      request = Request.new "GET", "/", headers
      request.cookies << Cookie.new("foo", "bar")

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar\r\n\r\n")
      headers.should eq(orignal_headers)
    end

    it "serialize GET (with cookies, from headers)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      headers["Cookie"] = "foo=bar"
      orignal_headers = headers.dup

      request = Request.new "GET", "/", headers

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar\r\n\r\n")

      request.cookies["foo"].value.should eq "bar" # Force lazy initialization

      io.clear
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar\r\n\r\n")

      request.cookies["foo"] = "baz"
      request.cookies["quux"] = "baz"

      io.clear
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=baz; quux=baz\r\n\r\n")
      headers.should eq(orignal_headers)
    end

    it "serialize POST (with body)" do
      request = Request.new "POST", "/", body: "thisisthebody"
      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")
    end

    it "serialize POST (with bytes body)" do
      request = Request.new "POST", "/", body: Bytes['a'.ord, 'b'.ord]
      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nContent-Length: 2\r\n\r\nab")
    end

    it "serialize POST (with io body, without content-length header)" do
      request = Request.new "POST", "/", body: IO::Memory.new("thisisthebody")
      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nd\r\nthisisthebody\r\n0\r\n\r\n")
    end

    it "serialize POST (with io body, with content-length header)" do
      string = "thisisthebody"
      request = Request.new "POST", "/", body: IO::Memory.new(string)
      request.content_length = string.bytesize
      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")
    end

    it "raises if serializing POST body with incorrect content-length (less then real)" do
      string = "thisisthebody"
      request = Request.new "POST", "/", body: IO::Memory.new(string)
      request.content_length = string.bytesize - 1
      io = IO::Memory.new
      expect_raises(ArgumentError) do
        request.to_io(io)
      end
    end

    it "raises if serializing POST body with incorrect content-length (more then real)" do
      string = "thisisthebody"
      request = Request.new "POST", "/", body: IO::Memory.new(string)
      request.content_length = string.bytesize + 1
      io = IO::Memory.new
      expect_raises(ArgumentError) do
        request.to_io(io)
      end
    end

    it "parses GET" do
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).as(Request)
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "parses GET with query params" do
      request = Request.from_io(IO::Memory.new("GET /greet?q=hello&name=world HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).as(Request)
      request.method.should eq("GET")
      request.path.should eq("/greet")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "parses GET without \\r" do
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\nHost: host.example.org\n\n")).as(Request)
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.example.org"})
    end

    it "parses empty header" do
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nReferer:\r\n\r\n")).as(Request)
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.example.org", "Referer" => ""})
    end

    it "parses GET with cookie" do
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: a=b\r\n\r\n")).as(Request)
      request.method.should eq("GET")
      request.path.should eq("/")
      request.cookies["a"].value.should eq("b")

      # Headers should not be modified (#2920)
      request.headers.should eq({"Host" => "host.example.org", "Cookie" => "a=b"})
    end

    it "headers are case insensitive" do
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).as(Request)
      headers = request.headers.not_nil!
      headers["HOST"].should eq("host.example.org")
      headers["host"].should eq("host.example.org")
      headers["Host"].should eq("host.example.org")
    end

    it "parses POST (with body)" do
      request = Request.from_io(IO::Memory.new("POST /foo HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")).as(Request)
      request.method.should eq("POST")
      request.path.should eq("/foo")
      request.headers.should eq({"Content-Length" => "13"})
      request.body.not_nil!.gets_to_end.should eq("thisisthebody")
    end

    it "handles malformed request" do
      request = Request.from_io(IO::Memory.new("nonsense"))
      request.should be_a(Request::BadRequest)
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nX-Test-Header: \u{0}\r\n"))
      request.should be_a(Request::BadRequest)
    end

    it "handles long request lines" do
      request = Request.from_io(IO::Memory.new("GET /#{"a" * 4096} HTTP/1.1\r\n\r\n"))
      request.should be_a(Request::BadRequest)
    end

    it "handles long headers" do
      request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\n#{"X-Test-Header: A pretty log header value\r\n" * 1000}\r\n"))
      request.should be_a(Request::BadRequest)
    end

    describe "keep-alive" do
      it "is false by default in HTTP/1.0" do
        request = Request.new "GET", "/", version: "HTTP/1.0"
        request.keep_alive?.should be_false
      end

      it "is true in HTTP/1.0 if `Connection: keep-alive` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "keep-alive"
        orignal_headers = headers.dup
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.0"
        request.keep_alive?.should be_true
        headers.should eq(orignal_headers)
      end

      it "is true by default in HTTP/1.1" do
        request = Request.new "GET", "/", version: "HTTP/1.1"
        request.keep_alive?.should be_true
      end

      it "is false in HTTP/1.1 if `Connection: close` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "close"
        orignal_headers = headers.dup
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.1"
        request.keep_alive?.should be_false
        headers.should eq(orignal_headers)
      end
    end

    describe "#path" do
      it "returns parsed path" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.path.should eq("/api/v3/some/resource")
      end

      it "falls back to /" do
        request = Request.new("GET", "/foo")
        request.path = nil
        request.path.should eq("/")
      end
    end

    describe "#path=" do
      it "sets path" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.path = "/api/v2/greet"
        request.path.should eq("/api/v2/greet")
      end

      it "updates @resource" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.path = "/api/v2/greet"
        request.resource.should eq("/api/v2/greet?filter=hello&world=test")
      end

      it "updates serialized form" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.path = "/api/v2/greet"

        io = IO::Memory.new
        request.to_io(io)
        io.to_s.should eq("GET /api/v2/greet?filter=hello&world=test HTTP/1.1\r\n\r\n")
      end
    end

    describe "#query" do
      it "returns request's query" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.query.should eq("filter=hello&world=test")
      end
    end

    describe "#query=" do
      it "sets query" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.query = "q=isearchforsomething&locale=de"
        request.query.should eq("q=isearchforsomething&locale=de")
      end

      it "updates @resource" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.query = "q=isearchforsomething&locale=de"
        request.resource.should eq("/api/v3/some/resource?q=isearchforsomething&locale=de")
      end

      it "updates serialized form" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.query = "q=isearchforsomething&locale=de"

        io = IO::Memory.new
        request.to_io(io)
        io.to_s.should eq("GET /api/v3/some/resource?q=isearchforsomething&locale=de HTTP/1.1\r\n\r\n")
      end
    end

    describe "#query_params" do
      it "returns parsed HTTP::Params" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        params["foo"].should eq("bar")
        params.fetch_all("foo").should eq(["bar", "baz"])
        params["baz"].should eq("qux")
      end

      it "happily parses when query is not a canonical url-encoded string" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?{\"hello\":\"world\"} HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params
        params["{\"hello\":\"world\"}"].should eq("")
        params.to_s.should eq("%7B%22hello%22%3A%22world%22%7D=")
      end

      it "affects #query when modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        params["foo"] = "not-bar"
        request.query.should eq("foo=not-bar&foo=baz&baz=qux")
      end

      it "updates @resource when modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        params["foo"] = "not-bar"
        request.resource.should eq("/api/v3/some/resource?foo=not-bar&foo=baz&baz=qux")
      end

      it "updates serialized form when modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        params["foo"] = "not-bar"

        io = IO::Memory.new
        request.to_io(io)
        io.to_s.should eq("GET /api/v3/some/resource?foo=not-bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")
      end

      it "is affected when #query is modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        new_query = "foo=not-bar&foo=not-baz&not-baz=hello&name=world"
        request.query = new_query
        request.query_params.to_s.should eq(new_query)
      end

      it "gets request host from the headers" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org:3000\r\nReferer:\r\n\r\n")).as(Request)
        request.host.should eq("host.example.org")
      end

      it "gets request host with port from the headers" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org:3000\r\nReferer:\r\n\r\n")).as(Request)
        request.host_with_port.should eq("host.example.org:3000")
      end
    end
  end
end
