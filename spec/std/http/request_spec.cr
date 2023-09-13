require "spec"
require "http/request"

private class EmptyIO < IO
  def read(slice : Bytes)
    0
  end

  def write(slice : Bytes) : Nil
  end
end

module HTTP
  describe Request do
    it "serialize GET" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      original_headers = headers.dup
      request = Request.new "GET", "/", headers

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")
      headers.should eq(original_headers)
    end

    it "serialize GET (with query params)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      original_headers = headers.dup
      request = Request.new "GET", "/greet?q=hello&name=world", headers

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET /greet?q=hello&name=world HTTP/1.1\r\nHost: host.example.org\r\n\r\n")
      headers.should eq(original_headers)
    end

    it "serialize GET (with cookie)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      original_headers = headers.dup
      request = Request.new "GET", "/", headers
      request.cookies << Cookie.new("foo", "bar")

      io = IO::Memory.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: foo=bar\r\n\r\n")
      headers.should eq(original_headers)
    end

    it "serialize GET (with cookies, from headers)" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.example.org"
      headers["Cookie"] = "foo=bar"
      original_headers = headers.dup

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
      headers.should eq(original_headers)
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

    describe ".from_io" do
      it "parses GET" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/")
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org"})
      end

      it "parses GET (just \\n instead of \\r\\n)" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\nHost: host.example.org\n\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/")
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org"})
      end

      it "parses GET with query params" do
        request = Request.from_io(IO::Memory.new("GET /greet?q=hello&name=world HTTP/1.1\r\nHost: host.example.org\r\n\r\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/greet")
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org"})
      end

      it "parses GET without \\r" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\nHost: host.example.org\n\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/")
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org"})
      end

      it "parses empty string (EOF), returns nil" do
        Request.from_io(IO::Memory.new("")).should be_nil
      end

      it "parses empty string (EOF), returns nil (no peek)" do
        Request.from_io(EmptyIO.new).should be_nil
      end

      it "parses GET with spaces in request line" do
        request = Request.from_io(IO::Memory.new("GET   /   HTTP/1.1  \r\nHost: host.example.org\r\n\r\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/")
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org"})
      end

      it "parses empty header" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nReferer:\r\n\r\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/")
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org", "Referer" => ""})
      end

      it "parses GET with cookie" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org\r\nCookie: a=b\r\n\r\n")).as(Request)
        request.method.should eq("GET")
        request.path.should eq("/")
        request.cookies["a"].value.should eq("b")

        # Headers should not be modified (#2920)
        request.headers.should eq(HTTP::Headers{"Host" => "host.example.org", "Cookie" => "a=b"})
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
        request.headers.should eq(HTTP::Headers{"Content-Length" => "13"})
        request.body.not_nil!.gets_to_end.should eq("thisisthebody")
      end

      it "handles malformed request" do
        request = Request.from_io(IO::Memory.new("nonsense"))
        request.should eq HTTP::Status::BAD_REQUEST
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nX-Test-Header: \u{0}\r\n"))
        request.should eq HTTP::Status::BAD_REQUEST
      end

      it "handles unsupported HTTP version" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.2\r\nContent-Length: 0\r\n\r\n"))
        request.should eq HTTP::Status::BAD_REQUEST
      end

      it "stores normalized case for common header name (lowercase) (#8060)" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\ncontent-type: foo\r\n\r\n")).as(Request)
        request.headers.to_s.should eq(%(HTTP::Headers{"content-type" => "foo"}))
      end

      it "stores normalized case for common header name (capitalized) (#8060)" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nContent-Type: foo\r\n\r\n")).as(Request)
        request.headers.to_s.should eq(%(HTTP::Headers{"Content-Type" => "foo"}))
      end

      it "stores normalized case for common header name (mixed) (#8060)" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nContent-type: foo\r\n\r\n")).as(Request)
        request.headers.to_s.should eq(%(HTTP::Headers{"Content-type" => "foo"}))
      end

      describe "long request lines" do
        it "handles long URI" do
          path = "a" * 8177
          request = Request.from_io(IO::Memory.new("GET /#{path} HTTP/1.1\r\n\r\n")).as(Request)
          request.path.count('a').should eq 8177
        end

        it "fails for too-long URI" do
          request = Request.from_io(IO::Memory.new("GET /#{"a" * 8192} HTTP/1.1\r\n\r\n"))
          request.should eq HTTP::Status::URI_TOO_LONG
        end

        it "handles long URI with custom size" do
          request = Request.from_io(IO::Memory.new("GET /12345 HTTP/1.1\r\n\r\n"), max_request_line_size: 20).as(Request)
          request.path.should eq "/12345"
        end

        it "fails for too-long URI with custom size" do
          request = Request.from_io(IO::Memory.new("GET /1234567 HTTP/1.1\r\n\r\n"), max_request_line_size: 20)
          request.should eq HTTP::Status::URI_TOO_LONG
        end
      end

      describe "long headers" do
        it "handles long headers" do
          request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\n#{"X-Test-Header: A pretty log header value\r\n" * 390}\r\n"))
          request.should be_a(Request)
          request.as(Request).headers["X-Test-Header"].should eq (["A pretty log header value"] * 390).join(',')
        end

        it "fails for too-long headers" do
          request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\n#{"X-Test-Header: A pretty log header value\r\n" * 391}\r\n"))
          request.should eq HTTP::Status::REQUEST_HEADER_FIELDS_TOO_LARGE
        end

        it "handles long headers with custom size" do
          request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo: Bar\r\n\r\n"), max_headers_size: 10)
          request.should be_a(Request)
          request.as(Request).headers["Foo"].should eq "Bar"
        end

        it "fails for too-long headers with custom size" do
          request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo: Bar!\r\n\r\n"), max_headers_size: 10)
          request.should eq HTTP::Status::REQUEST_HEADER_FIELDS_TOO_LARGE
        end
      end

      describe "long single header" do
        it "handles long header" do
          request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo: #{"b" * 16377}\r\n\r\n"))
          request.should be_a(Request)
          request.as(Request).headers["Foo"].size.should eq 16377
        end

        it "fails for too-long header" do
          request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo: #{"b" * 16378}\r\n"))
          request.should eq HTTP::Status::REQUEST_HEADER_FIELDS_TOO_LARGE
        end
      end
    end

    describe "keep-alive" do
      it "is false by default in HTTP/1.0" do
        request = Request.new "GET", "/", version: "HTTP/1.0"
        request.keep_alive?.should be_false
      end

      it "is true in HTTP/1.0 if `Connection: keep-alive` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "keep-alive"
        original_headers = headers.dup
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.0"
        request.keep_alive?.should be_true
        headers.should eq(original_headers)
      end

      it "is true by default in HTTP/1.1" do
        request = Request.new "GET", "/", version: "HTTP/1.1"
        request.keep_alive?.should be_true
      end

      it "is false in HTTP/1.1 if `Connection: close` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "close"
        original_headers = headers.dup
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.1"
        request.keep_alive?.should be_false
        headers.should eq(original_headers)
      end
    end

    describe "#path" do
      it "returns parsed path" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).as(Request)
        request.path.should eq("/api/v3/some/resource")
      end

      it "falls back to /" do
        request = Request.new("GET", "")
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
      it "returns parsed URI::Params" do
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
        request.query.should eq("foo=not-bar&baz=qux")
      end

      it "updates @resource when modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        params["foo"] = "not-bar"
        request.resource.should eq("/api/v3/some/resource?foo=not-bar&baz=qux")
      end

      it "updates serialized form when modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        params["foo"] = "not-bar"

        io = IO::Memory.new
        request.to_io(io)
        io.to_s.should eq("GET /api/v3/some/resource?foo=not-bar&baz=qux HTTP/1.1\r\n\r\n")
      end

      it "is affected when #query is modified" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?foo=bar&foo=baz&baz=qux HTTP/1.1\r\n\r\n")).as(Request)
        params = request.query_params

        new_query = "foo=not-bar&foo=not-baz&not-baz=hello&name=world"
        request.query = new_query
        request.query_params.to_s.should eq(new_query)
      end
    end

    describe "#form_params" do
      it "returns can safely be called on get requests" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource HTTP/1.1\r\n\r\n")).as(Request)
        request.form_params?.should eq(nil)
        request.form_params.size.should eq(0)
      end

      it "returns parsed HTTP::Params" do
        request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should_not eq(nil)
        request.form_params.size.should eq(1)
        request.form_params["test"].should eq("foobar")
      end

      it "returns ignors invalid content-type" do
        request = Request.new("POST", "/form", nil, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should eq(nil)
        request.form_params.size.should eq(0)
      end
    end

    describe "#hostname" do
      it "gets request hostname from the headers" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org:3000\r\nReferer:\r\n\r\n")).as(Request)
        request.hostname.should eq("host.example.org")
      end

      it "#hostname" do
        request = Request.new("GET", "/", HTTP::Headers{"Host" => "host.example.org"})
        request.hostname.should eq("host.example.org")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "0.0.0.0"})
        request.hostname.should eq("0.0.0.0")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "[1234:5678::1]"})
        request.hostname.should eq("1234:5678::1")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "[::1]"})
        request.hostname.should eq("::1")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "host.example.org:3000"})
        request.hostname.should eq("host.example.org")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "0.0.0.0:3000"})
        request.hostname.should eq("0.0.0.0")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "[1234:5678::1]:80"})
        request.hostname.should eq("1234:5678::1")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "[::1]:3000"})
        request.hostname.should eq("::1")

        request = Request.new("GET", "/")
        request.hostname.should be_nil
      end
    end

    describe "#host_with_port" do
      it "gets request host with port from the headers" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org:3000\r\nReferer:\r\n\r\n")).as(Request)
        request.host_with_port.should eq("host.example.org:3000")
      end
    end

    it "doesn't raise on request with multiple Content_length headers" do
      io = IO::Memory.new <<-HTTP
        GET / HTTP/1.1
        Host: host
        Content-Length: 5
        Content-Length: 5
        Content-Type: text/plain

        abcde
        HTTP
      HTTP::Request.from_io(io)
    end

    it "raises if request has multiple and differing content-length headers" do
      io = IO::Memory.new <<-HTTP
        GET / HTTP/1.1
        Host: host
        Content-Length: 5
        Content-Length: 6
        Content-Type: text/plain

        abcde
        HTTP
      expect_raises(ArgumentError) do
        HTTP::Request.from_io(io)
      end
    end

    describe "#if_none_match" do
      it "reads single value" do
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(W/"1234567")}).if_none_match.should eq [%(W/"1234567")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %("1234567")}).if_none_match.should eq [%("1234567")]
      end

      it "reads *" do
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => "*"}).if_none_match.should eq ["*"]
      end

      it "reads multiple values" do
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(,W/"1234567",)}).if_none_match.should eq [%(W/"1234567")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(, , W/"1234567" , ,)}).if_none_match.should eq [%(W/"1234567")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(W/"1234567",W/"12345678")}).if_none_match.should eq [%(W/"1234567"), %(W/"12345678")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(W/"1234567" , W/"12345678")}).if_none_match.should eq [%(W/"1234567"), %(W/"12345678")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(W/"1234567","12345678")}).if_none_match.should eq [%(W/"1234567"), %("12345678")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => %(W/"1234567" , "12345678")}).if_none_match.should eq [%(W/"1234567"), %("12345678")]
      end
    end

    describe "#if_match" do
      it "reads single value" do
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(W/"1234567")}).if_match.should eq [%(W/"1234567")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %("1234567")}).if_match.should eq [%("1234567")]
      end

      it "reads *" do
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => "*"}).if_match.should eq ["*"]
      end

      it "reads multiple values" do
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(,W/"1234567",)}).if_match.should eq [%(W/"1234567")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(, , W/"1234567" , ,)}).if_match.should eq [%(W/"1234567")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(W/"1234567",W/"12345678")}).if_match.should eq [%(W/"1234567"), %(W/"12345678")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(W/"1234567" , W/"12345678")}).if_match.should eq [%(W/"1234567"), %(W/"12345678")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(W/"1234567","12345678")}).if_match.should eq [%(W/"1234567"), %("12345678")]
        HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => %(W/"1234567" , "12345678")}).if_match.should eq [%(W/"1234567"), %("12345678")]
      end
    end
  end
end
