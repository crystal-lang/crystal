#!/usr/bin/env bin/crystal --run
require "spec"
require "net/http"

describe "HTTP client" do
  it "performs GET request" do
    request = HTTPRequest.new "localhost", 8080, :get, "/", {"Host" => "host.domain.com"} of String => String
    io = String::Buffer.new
    request.to_io(io)
    io.to_s.should eq("GET / HTTP/1.1\r\nHost: host.domain.com\r\n\r\n")
  end

  it "gets response" do
    response = HTTPResponse.from_io(StringIO.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhelloworld"))
    response.version.should eq("HTTP/1.1")
    response.status_code.should eq(200)
    response.status_message.should eq("OK")
    response.headers["content-type"].should eq("text/plain")
    response.headers["content-length"].should eq("5")
    response.body.should eq("hello")
  end
end
