#!/usr/bin/env bin/crystal --run
require "spec"
require "net/http"

describe "HTTP" do
  describe "Request" do
    it "serialize GET" do
      request = HTTP::Request.new :get, "/", {"Host" => "host.domain.com"}
      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n")
    end

    it "serialize POST (with body)" do
      request = HTTP::Request.new :post, "/", body: "thisisthebody"
      io = StringIO.new
      request.to_io(io)
      io.to_s.should eq("POST / HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody")
    end

    it "parses GET" do
      request = HTTP::Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n"))
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.domain.com"})
    end

    it "parses GET without \\r" do
      request = HTTP::Request.from_io(StringIO.new("GET / HTTP/1.1\nHost: host.domain.com\n\n"))
      request.method.should eq("GET")
      request.path.should eq("/")
      request.headers.should eq({"Host" => "host.domain.com"})
    end

    it "headers are case insensitive" do
      request = HTTP::Request.from_io(StringIO.new("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n"))
      headers = request.headers.not_nil!
      headers["HOST"].should eq("host.domain.com")
      headers["host"].should eq("host.domain.com")
      headers["Host"].should eq("host.domain.com")
    end

    it "parses POST (with body)" do
      request = HTTP::Request.from_io(StringIO.new("POST /foo HTTP/1.1\r\nContent-Length: 13\r\n\r\nthisisthebody"))
      request.method.should eq("POST")
      request.path.should eq("/foo")
      request.headers.should eq({"Content-Length" => "13"})
      request.body.should eq("thisisthebody")
    end
  end

  describe "Response" do
    it "parses response with body" do
      response = HTTP::Response.from_io(StringIO.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body.should eq("hello")
    end

    it "parses response with body without \\r" do
      response = HTTP::Response.from_io(StringIO.new("HTTP/1.1 200 OK\nContent-Type: text/plain\nContent-Length: 5\n\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body.should eq("hello")
    end

    it "parses response without body" do
      response = HTTP::Response.from_io(StringIO.new("HTTP/1.1 404 Not Found\r\n\r\n"))
      response.status_code.should eq(404)
      response.status_message.should eq("Not Found")
      response.headers.length.should eq(0)
      response.body.should be_nil
    end

    it "parses response with chunked body" do
      response = HTTP::Response.from_io(io = StringIO.new("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabcde\r\na\r\n0123456789\r\n0\r\n"))
      response.body.should eq("abcde0123456789")
      io.gets.should be_nil
    end

    it "serialize with body" do
      response = HTTP::Response.new(200, "hello", {"Content-Type" => "text/plain", "Content-Length" => "5"})
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhello")
    end

    it "sets content length from body" do
      response = HTTP::Response.new(200, "hello")
      response.headers["Content-Length"].should eq("5")
    end

    it "builds default not found" do
      response = HTTP::Response.not_found
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\n\r\nNot Found")
    end

    it "builds default ok response" do
      response = HTTP::Response.ok("text/plain", "Hello")
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
    end

    it "builds default error response" do
      response = HTTP::Response.error("text/plain", "Error!")
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nContent-Length: 6\r\n\r\nError!")
    end
  end
end
