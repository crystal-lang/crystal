require "spec"
require "http/request"

module HTTP
  describe Request do
    it "serialize GET" do
      headers = HTTP::Headers.new
      headers["Host"] = "host.domain.com"
      request = Request.new "GET", "/", headers

      io = StringIO.new
      request.to_io(io)
      expect(io.to_s).to eq("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n")
    end

    it "serialize POST (with body)" do
      request = Request.new "POST", "/", body: "thisisthebody"
      io = StringIO.new
      request.to_io(io)
      expect(io.to_s).to eq("POST / HTTP/1.1\r\nContent-length: 13\r\n\r\nthisisthebody")
    end

    it "parses GET" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n")).not_nil!
      expect(request.method).to eq("GET")
      expect(request.path).to eq("/")
      expect(request.headers).to eq({"Host" => "host.domain.com"})
    end

    it "parses GET without \\r" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\nHost: host.domain.com\n\n")).not_nil!
      expect(request.method).to eq("GET")
      expect(request.path).to eq("/")
      expect(request.headers).to eq({"Host" => "host.domain.com"})
    end

    it "headers are case insensitive" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n")).not_nil!
      headers = request.headers.not_nil!
      expect(headers["HOST"]).to eq("host.domain.com")
      expect(headers["host"]).to eq("host.domain.com")
      expect(headers["Host"]).to eq("host.domain.com")
    end

    it "parses POST (with body)" do
      request = Request.from_io(StringIO.new("POST /foo HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")).not_nil!
      expect(request.method).to eq("POST")
      expect(request.path).to eq("/foo")
      expect(request.headers).to eq({"Content-Length" => "13"})
      expect(request.body).to eq("thisisthebody")
    end

    describe "keep-alive" do
      it "is false by default in HTTP/1.0" do
        request = Request.new "GET", "/", version: "HTTP/1.0"
        expect(request.keep_alive?).to be_false
      end

      it "is true in HTTP/1.0 if `Connection: keep-alive` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "keep-alive"
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.0"
        expect(request.keep_alive?).to be_true
      end

      it "is true by default in HTTP/1.1" do
        request = Request.new "GET", "/", version: "HTTP/1.1"
        expect(request.keep_alive?).to be_true
      end

      it "is false in HTTP/1.1 if `Connection: close` header is present" do
        headers = HTTP::Headers.new
        headers["Connection"] = "close"
        request = Request.new "GET", "/", headers: headers, version: "HTTP/1.1"
        expect(request.keep_alive?).to be_false
      end
    end
  end
end
