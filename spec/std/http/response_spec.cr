require "spec"
require "http/response"

module HTTP
  describe Response do
    it "parses response with body" do
      response = Response.from_io(StringIO.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body?.should be_true
      response.body.should eq("hello")
    end

    it "parses response with body without \\r" do
      response = Response.from_io(StringIO.new("HTTP/1.1 200 OK\nContent-Type: text/plain\nContent-Length: 5\n\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body?.should be_true
      response.body.should eq("hello")
    end

    it "parses response with empty body" do
      response = Response.from_io(StringIO.new("HTTP/1.1 404 Not Found\r\n\r\n"))
      response.status_code.should eq(404)
      response.status_message.should eq("Not Found")
      response.headers["content-length"].should eq("0")
      response.body?.should be_true
      response.body.should eq("")
    end

    it "parses response without body" do
      response = Response.from_io(StringIO.new("HTTP/1.1 100 Continue\r\n\r\n"))
      response.status_code.should eq(100)
      response.status_message.should eq("Continue")
      response.headers.length.should eq(0)
      response.body?.should be_false
      response.body.should eq("")
    end

    it "parses response with body but without Content-length" do
      response = Response.from_io(StringIO.new("HTTP/1.1 200 OK\r\n\r\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers.length.should eq(0)
      response.body?.should be_true
      response.body.should eq("helloworld")
    end

    it "parses response with duplicated headers" do
      response = Response.from_io(StringIO.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nSet-Cookie: a=b\r\nSet-Cookie: c=d\r\n\r\nhelloworld"))
      response.headers.get("Set-Cookie").should eq(["a=b", "c=d"])
    end

    it "parses response with chunked body" do
      response = Response.from_io(io = StringIO.new("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabcde\r\na\r\n0123456789\r\n0\r\n"))
      response.body.should eq("abcde0123456789")
      io.gets.should be_nil
    end

    it "serialize with body" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "text/plain"
      headers["Content-Length"] = "5"

      response = Response.new(200, "hello", headers)
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-type: text/plain\r\nContent-length: 5\r\n\r\nhello")
    end

    it "sets content length from body" do
      response = Response.new(200, "hello")
      response.headers["Content-Length"].should eq("5")
    end

    it "sets content length even without body" do
      response = Response.new(200)
      response.headers["Content-Length"].should eq("0")
    end

    it "doesn't sets content length for 1xx, 204 or 304" do
      [100, 101, 204, 304].each do |status|
        response = Response.new(status)
        response.headers.length.should eq(0)
      end
    end

    it "raises when creating 1xx, 204 or 304 with body" do
      errors = 0
      [100, 101, 204, 304].each do |status|
        begin
          Response.new(status, "hello")
        rescue ArgumentError
          errors += 1
        end
      end
      errors.should eq(4)
    end
    
    it "allows reading the body as an IO" do
      response = Response.from_io(StringIO.new("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhelloworld"))
      response.body?.should be_true
      response.body_io.read(3).should eq("hel")
      response.body_io.read.should eq("lo")
    end
    
    it "raises when trying to fetch the body after an IO read" do
      error = nil
      begin
        response = Response.from_io(StringIO.new("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhelloworld"))
        response.body_io.read(3)
        response.body
      rescue ex
        error = ex
      end
      error.should be_a(ArgumentError)
    end

    it "builds default not found" do
      response = Response.not_found
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 404 Not Found\r\nContent-type: text/plain\r\nContent-length: 9\r\n\r\nNot Found")
    end

    it "builds default ok response" do
      response = Response.ok("text/plain", "Hello")
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-type: text/plain\r\nContent-length: 5\r\n\r\nHello")
    end

    it "builds default error response" do
      response = Response.error("text/plain", "Error!")
      io = StringIO.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 500 Internal Server Error\r\nContent-type: text/plain\r\nContent-length: 6\r\n\r\nError!")
    end
  end
end
