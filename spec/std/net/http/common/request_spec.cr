#!/usr/bin/env bin/crystal --run
require "spec"
require "net/http"

module HTTP
  describe Request do
    it "serialize GET" do
      request = Request.new :get, "/", {"Host" => "host.domain.com"}
      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n")
    end

    it "serialize POST (with body)" do
      request = Request.new :post, "/", body: "thisisthebody"
      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")
    end

    it "parses GET" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n"))
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.domain.com"})
    end

    it "parses GET without \\r" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\nHost: host.domain.com\n\n"))
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.domain.com"})
    end

    it "headers are case insensitive" do
      request = Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n"))
      headers = request.headers.not_nil!
      headers["HOST"].should eq("host.domain.com")
      headers["host"].should eq("host.domain.com")
      headers["Host"].should eq("host.domain.com")
    end

    it "parses POST (with body)" do
      request = Request.from_io(StringIO.new("POST /foo HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody"))
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
        request = Request.new "GET", "/", headers: {"Connection" => "keep-alive"}, version: "HTTP/1.0"
        request.keep_alive?.should be_true
      end

      it "is true by default in HTTP/1.1" do
        request = Request.new "GET", "/", version: "HTTP/1.1"
        request.keep_alive?.should be_true
      end

      it "is false in HTTP/1.1 if `Connection: close` header is present" do
        request = Request.new "GET", "/", headers: {"Connection" => "close"}, version: "HTTP/1.1"
        request.keep_alive?.should be_false
      end
    end
  end
end
