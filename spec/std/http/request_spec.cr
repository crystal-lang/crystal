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
    describe ".new" do
      context "method" do
        it "accepts standard methods" do
          Request.new "GET", "/"
          Request.new "POST", "/"
          Request.new "PUT", "/"
          Request.new "DELETE", "/"
          Request.new "PATCH", "/"
        end

        it "accepts unknown methods" do
          Request.new "FOO", "/"
          Request.new "bar", "/"
        end

        it "rejects invalid methods" do
          expect_raises(ArgumentError, "Invalid HTTP method") { Request.new "GET /", "/" }
          expect_raises(ArgumentError, "Invalid HTTP method") { Request.new "GET\n", "/" }
          expect_raises(ArgumentError, "Invalid HTTP method") { Request.new "GET\r", "/" }
          expect_raises(ArgumentError, "Invalid HTTP method") { Request.new "", "/" }
        end
      end

      context "resource" do
        it "accepts valid resource target" do
          Request.new "GET", "/"
          Request.new "GET", "/foo/bar"
          Request.new "GET", "/foo/bar?baz=qux"
        end

        it "rejects invalid resource target" do
          expect_raises(ArgumentError, "Invalid HTTP resource: \"foo /\"") { Request.new "GET", "foo /" }
          expect_raises(ArgumentError, "Invalid HTTP resource: \"foo\\n\"") { Request.new "GET", "foo\n" }
          expect_raises(ArgumentError, "Invalid HTTP resource: \"foo\\r\"") { Request.new "GET", "foo\r" }
          expect_raises(ArgumentError, "Invalid HTTP resource: \"\"") { Request.new "GET", "" }
        end

        describe "target forms" do
          describe "origin-form" do
            it "accepts origin-form" do
              req = Request.new "GET", "/foo/bar"
              String.build { |io| req.to_io(io) }.should eq "GET /foo/bar HTTP/1.1\r\n\r\n"
            end
          end

          describe "absolute-form" do
            it "accepts absolute-form" do
              req = Request.new "GET", "http://example.com/foo/bar"
              String.build { |io| req.to_io(io) }.should eq "GET http://example.com/foo/bar HTTP/1.1\r\n\r\n"
            end
          end

          describe "authority-form" do
            it "accepts authority-form" do
              req = Request.new "CONNECT", "proxy.example.com:80"
              String.build { |io| req.to_io(io) }.should eq "CONNECT proxy.example.com:80 HTTP/1.1\r\n\r\n"
            end
          end

          describe "asterisk-form" do
            it "accepts asterisk-form" do
              req = Request.new "OPTIONS", "*"
              String.build { |io| req.to_io(io) }.should eq "OPTIONS * HTTP/1.1\r\n\r\n"
            end
          end
        end
      end

      context "version" do
        it "accepts valid HTTP versions" do
          Request.new("GET", "/", version: "HTTP/1.0")
          Request.new("GET", "/", version: "HTTP/1.1")
        end

        it "rejects invalid HTTP versions" do
          expect_raises(ArgumentError, "Unsupported HTTP version: HTTP/1.2") do
            Request.new("GET", "/", version: "HTTP/1.2")
          end
          expect_raises(ArgumentError, "Unsupported HTTP version: HTTP/3.0") do
            Request.new("GET", "/", version: "HTTP/3.0")
          end
          expect_raises(ArgumentError, "Unsupported HTTP version: INVALID") do
            Request.new("GET", "/", version: "INVALID")
          end
        end
      end
    end

    describe "#method=" do
      it "accepts standard methods" do
        Request.new("GET", "/").method = "GET"
        Request.new("GET", "/").method = "POST"
        Request.new("GET", "/").method = "PUT"
        Request.new("GET", "/").method = "DELETE"
        Request.new("GET", "/").method = "PATCH"
      end

      it "accepts unknown methods" do
        Request.new("GET", "/").method = "FOO"
        Request.new("GET", "/").method = "bar"
      end

      it "rejects invalid methods" do
        req = Request.new("GET", "/")
        expect_raises(ArgumentError, "Invalid HTTP method") { req.method = "GET /" }
        expect_raises(ArgumentError, "Invalid HTTP method") { req.method = "GET\n" }
        expect_raises(ArgumentError, "Invalid HTTP method") { req.method = "GET\r" }
        expect_raises(ArgumentError, "Invalid HTTP method") { req.method = "" }
      end
    end

    describe "#path=" do
      it "accepts valid path" do
        req = Request.new "GET", "/"
        req.path = "/foo/bar"
        req.path.should eq "/foo/bar"
        req.path = "/foo/bar?baz=qux"
        req.path.should eq "/foo/bar?baz=qux"
        req.path = "/"
        req.path.should eq "/"

        req.path = "foo%20bar"
        req.path.should eq "foo%20bar"
      end

      it "rejects invalid path" do
        req = Request.new "GET", "/"
        expect_raises(ArgumentError, "Invalid HTTP resource") do
          req.path = "foo\r"
        end
        expect_raises(ArgumentError, "Invalid HTTP resource") do
          req.path = "\r"
        end
      end

      it "accepts empty path" do
        req = Request.new "GET", "/foo"
        req.path = ""
        req.path.should eq "/"
        req.resource.should eq "/"
      end
    end

    describe "#version=" do
      it "accepts valid HTTP versions" do
        req = Request.new("GET", "/")
        req.version = "HTTP/1.0"
        req.version.should eq "HTTP/1.0"
        req.version = "HTTP/1.1"
        req.version.should eq "HTTP/1.1"
      end

      it "rejects invalid HTTP versions" do
        req = Request.new("GET", "/")
        expect_raises(ArgumentError, "Unsupported HTTP version: HTTP/1.2") do
          req.version = "HTTP/1.2"
        end
        expect_raises(ArgumentError, "Unsupported HTTP version: HTTP/3.0") do
          req.version = "HTTP/3.0"
        end
        expect_raises(ArgumentError, "Unsupported HTTP version: INVALID") do
          req.version = "INVALID"
        end
      end
    end

    describe "#body=" do
      it "returns the value" do
        req = Request.new("GET", "/")
        (req.body = "foo").should eq "foo"
        (req.body = "foo".to_slice).should eq "foo".to_slice
        io = IO::Memory.new
        (req.body = io).should be io
        (req.body = nil).should be_nil
      end

      it "keeps content-length header in sync" do
        # BUG: The following specs all demonstrate incorrect behaviour.
        req = Request.new("GET", "/", body: "foo")
        req.body = IO::Memory.new("")
        req.method = "POST"
        req.content_length.should eq 3
        String.build do |io|
          expect_raises(ArgumentError, "Content-Length header is 3 but body had 0 bytes") do
            req.to_io(io)
          end
        end
      end

      it "keeps content-length header in sync" do
        # BUG: The following specs all demonstrate incorrect behaviour.
        req = Request.new("PATCH", "/", body: "foo")
        req.body = nil
        req.content_length.should eq 3
        String.build do |io|
          req.to_io(io)
        end.should eq "PATCH / HTTP/1.1\r\nContent-Length: 3\r\n\r\n"
      end
    end

    describe "#content_length=" do
      it "accepts valid values" do
        req = Request.new("GET", "/")
        (req.content_length = 1234).should eq 1234
        req.content_length.should eq 1234
        req.headers["Content-Length"].should eq "1234"

        (req.content_length = 0).should eq 0
        req.content_length.should eq 0
        req.headers["Content-Length"].should eq "0"

        (req.content_length = UInt64::MAX).should eq UInt64::MAX
        req.content_length.should eq UInt64::MAX
        req.headers["Content-Length"].should eq UInt64::MAX.to_s
      end

      it "rejects invalid values" do
        # BUG: The following specs all demonstrate incorrect behaviour.
        req = Request.new("GET", "/")
        req.content_length = -1
        req.headers["Content-Length"].should eq "-1"
        req.content_length = -1234
        req.headers["Content-Length"].should eq "-1234"
        req.content_length = UInt64::MAX.to_i128 + 1
        req.headers["Content-Length"].should eq (UInt64::MAX.to_i128 + 1).to_s
      end
    end

    describe "#to_io" do
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

      it "validates resource after unobserved modification" do
        request = Request.new "GET", "/"
        request.uri.path = "foo bar"
        io = IO::Memory.new
        expect_raises(ArgumentError, %(Invalid HTTP resource: "foo bar")) do
          request.to_io(io)
        end
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
        headers = request.headers.should_not(be_nil)
        headers["HOST"].should eq("host.example.org")
        headers["host"].should eq("host.example.org")
        headers["Host"].should eq("host.example.org")
      end

      it "parses POST (with body)" do
        request = Request.from_io(IO::Memory.new("POST /foo HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")).as(Request)
        request.method.should eq("POST")
        request.path.should eq("/foo")
        request.headers.should eq(HTTP::Headers{"Content-Length" => "13"})
        request.body.should_not(be_nil).gets_to_end.should eq("thisisthebody")
      end

      it "handles malformed request" do
        request = Request.from_io(IO::Memory.new("nonsense"))
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

      describe "invalid headers" do
        it "empty header name" do
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\n: Bar\r\n\r\n")).should eq HTTP::Status::BAD_REQUEST
        end

        it "header without colon" do
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo Bar\r\n\r\n")).should eq HTTP::Status::BAD_REQUEST
        end

        it "invalid header name" do
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo Bar: baz\r\n")).should eq HTTP::Status::BAD_REQUEST
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo\tBar: baz\r\n")).should eq HTTP::Status::BAD_REQUEST
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo[Bar: baz\r\n")).should eq HTTP::Status::BAD_REQUEST
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nFoo\0Bar: baz\r\n")).should eq HTTP::Status::BAD_REQUEST
        end

        it "invalid header value" do
          Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nX-Test-Header: \u{0}\r\n")).should eq HTTP::Status::BAD_REQUEST
        end

        it "doesn't raise on request with multiple Content-Length headers" do
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

        it "raises if request has multiple and differing Content-Length headers" do
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
      end

      it "rejects unhandled Transfer-Encoding" do
        request = Request.from_io(IO::Memory.new(<<-HTTP)).should eq HTTP::Status::NOT_IMPLEMENTED
          GET / HTTP/1.1
          Transfer-Encoding: deflate

          Hello

          HTTP
      end

      it "rejects unknown Transfer-Encoding" do
        request = Request.from_io(IO::Memory.new(<<-HTTP)).should eq HTTP::Status::NOT_IMPLEMENTED
          GET / HTTP/1.1
          Transfer-Encoding: foobar

          Hello

          HTTP
      end

      it "accepts multiple identical Content-Length headers" do
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

      it "raises on multiple differing Content-Length headers" do
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
    end

    describe "#keep_alive?" do
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
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource?filter=hello&world=test HTTP/1.1\r\n\r\n")).should be_a(Request)
        request.path.should eq("/api/v3/some/resource")
      end

      it "parses with only leading with double slash" do
        HTTP::Request.new("GET", "//").path.should eq "//"
      end

      it "parses path leading with double slash" do
        Request.new("GET", "//foo:bar").path.should eq "//foo:bar"
      end

      it "parses path leading with scheme" do
        Request.new("GET", "http://example.com/foo/bar").path.should eq "http://example.com/foo/bar"
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

      it "rejects invalid query" do
        request = Request.new "GET", "/"
        expect_raises(ArgumentError, "Invalid HTTP resource: \"/?foo bar\"") do
          request.query = "foo bar"
        end
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

        new_query = "foo=not-bar&foo=not-baz&not-baz=hello&name=world"
        request.query = new_query
        request.query_params.to_s.should eq(new_query)
      end
    end

    describe "#form_params" do
      it "returns can safely be called on get requests" do
        request = Request.from_io(IO::Memory.new("GET /api/v3/some/resource HTTP/1.1\r\n\r\n")).as(Request)
        request.form_params?.should be_nil
        request.form_params.size.should eq(0)
      end

      it "returns parsed HTTP::Params" do
        request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should_not be_nil
        request.form_params.size.should eq(1)
        request.form_params["test"].should eq("foobar")
      end

      it "accepts media type parameters" do
        request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"}, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should_not be_nil
        request.form_params.size.should eq(1)
        request.form_params["test"].should eq("foobar")
      end

      {% unless flag?(:without_iconv) %}
        it "accepts non-UTF8 media type parameters" do
          request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; charset=UCS-2LE"}, HTTP::Params.encode({"test" => "foobar"}).encode("UCS-2LE"))
          request.form_params?.should_not be_nil
          request.form_params.size.should eq(1)
          request.form_params["test"].should eq("foobar")
        end
      {% end %}

      it "accepts arbitrary media type parameters" do
        request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded; baz=qux"}, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should_not be_nil
        request.form_params.size.should eq(1)
        request.form_params["test"].should eq("foobar")
      end

      it "ignores missing content-type" do
        request = Request.new("POST", "/form", nil, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should be_nil
        request.form_params.size.should eq(0)
      end

      it "ignores unknown content-type" do
        request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "unknown/type"}, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should be_nil
        request.form_params.size.should eq(0)
      end

      it "ignores invalid content-type" do
        request = Request.new("POST", "/form", HTTP::Headers{"Content-Type" => "//"}, HTTP::Params.encode({"test" => "foobar"}))
        request.form_params?.should be_nil
        request.form_params.size.should eq(0)
      end
    end

    describe "#hostname" do
      it "gets request hostname from the headers" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org:3000\r\nReferer:\r\n\r\n")).as(Request)
        request.hostname.should eq("host.example.org")
      end

      it "extracts hostname" do
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

        Request.new("GET", "/", HTTP::Headers{"Host" => "host.:3000"}).hostname.should eq "host."

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "0.0.0.0:3000"})
        request.hostname.should eq("0.0.0.0")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "[1234:5678::1]:80"})
        request.hostname.should eq("1234:5678::1")

        request = Request.new("GET", "/", HTTP::Headers{"Host" => "[::1]:3000"})
        request.hostname.should eq("::1")

        request = Request.new("GET", "/")
        request.hostname.should be_nil
      end

      it "rejects invalid hostnames" do
        Request.new("GET", "/", HTTP::Headers{"Host" => "host.example.org:3000:4000"}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => "host.example.org:"}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => "host.example.org:bar"}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => "host.example.org:80bar"}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => "[1234:5678::1]:80:90"}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => "::1"}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => ["foo", "bar"]}).hostname.should be_nil
      end

      it "returns nil for empty hostname" do
        Request.new("GET", "/", HTTP::Headers{"Host" => ""}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => ":4000"}).hostname.should be_nil
      end

      it "returns nil when there are multiple headers" do
        Request.new("GET", "/", HTTP::Headers{"Host" => ["foo", "bar"]}).hostname.should be_nil
        Request.new("GET", "/", HTTP::Headers{"Host" => ["", ""]}).hostname.should be_nil
      end
    end

    describe "#host_with_port" do
      it "gets request host with port from the headers" do
        request = Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\nHost: host.example.org:3000\r\nReferer:\r\n\r\n")).as(Request)
        request.host_with_port.should eq("host.example.org:3000")
      end
    end

    describe "#uri" do
      it "returns request uri object" do
        raw_resource = "/document?something=true#fragment"
        request = Request.from_io(IO::Memory.new("GET #{raw_resource} HTTP/1.1\r\n\r\n")).as(Request)
        request.uri.should eq(URI.parse(raw_resource))
      end

      it "can change the results of #resource" do
        request = Request.from_io(IO::Memory.new("GET /route HTTP/1.1\r\n\r\n")).as(Request)
        request.resource.should eq("/route")

        request.uri.path = "/some_other_route"
        request.resource.should eq("/some_other_route")
      end
    end

    describe "#resource" do
      it "validates after unobserved modification" do
        request = Request.new "GET", "/"
        request.uri.path = "foo bar"
        expect_raises(ArgumentError, %(Invalid HTTP resource: "foo bar")) do
          request.resource
        end
        request.uri.path = "\r"
        expect_raises(ArgumentError, %(Invalid HTTP resource: "\\r")) do
          request.resource
        end
      end

      it "always yields a valid resource for arbitrary query_params" do
        request = Request.new "GET", "/"
        request.query_params["x a"] = "foo\rbar"
        request.resource.should eq "/?x+a=foo%0Dbar"
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

    describe "#replayable?" do
      it "GET is replayable" do
        HTTP::Request.new("GET", "/").replayable?.should be_true
      end

      it "GET with body is not replayable" do
        HTTP::Request.new("GET", "/", body: "body").replayable?.should be_false
      end

      it "POST is not replayable" do
        HTTP::Request.new("POST", "/").replayable?.should be_false
      end

      it "POST with Idempotency-Key header is replayable" do
        HTTP::Request.new("POST", "/", HTTP::Headers{"Idempotency-Key" => "key"}).replayable?.should be_true
      end

      it "POST with X-Idempotency-Key header is replayable" do
        HTTP::Request.new("POST", "/", HTTP::Headers{"X-Idempotency-Key" => "key"}).replayable?.should be_true
      end

      it "POST with body and Idempotency-Key header is not replayable" do
        HTTP::Request.new("POST", "/", HTTP::Headers{"Idempotency-Key" => "key"}, "body").replayable?.should be_false
      end
    end
  end
end
