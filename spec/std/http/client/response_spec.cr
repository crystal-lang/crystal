require "spec"
require "http/client/response"

class HTTP::Client
  describe Response do
    it "parses response with body" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body.should eq("hello")
    end

    it "parses response with streamed body" do
      Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhelloworld")) do |response|
        response.version.should eq("HTTP/1.1")
        response.status_code.should eq(200)
        response.status_message.should eq("OK")
        response.headers["content-type"].should eq("text/plain")
        response.headers["content-length"].should eq("5")
        response.body?.should be_nil
        response.body_io.gets_to_end.should eq("hello")
      end
    end

    it "parses response with streamed body, huge content-length" do
      Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{UInt64::MAX}\r\n\r\nhelloworld")) do |response|
        response.headers["content-length"].should eq("#{UInt64::MAX}")
      end
    end

    it "parses response with body without \\r" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\nContent-Type: text/plain\nContent-Length: 5\n\nhelloworld"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body.should eq("hello")
    end

    it "parses response with body but without content-length" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\n\r\nhelloworld"))
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers.size.should eq(0)
      response.body.should eq("helloworld")
    end

    it "parses response with empty body but without content-length" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 404 Not Found\r\n\r\n"))
      response.status_code.should eq(404)
      response.status_message.should eq("Not Found")
      response.headers.size.should eq(0)
      response.body.should eq("")
    end

    it "parses response without body" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 100 Continue\r\n\r\n"))
      response.status_code.should eq(100)
      response.status_message.should eq("Continue")
      response.headers.size.should eq(0)
      response.body?.should be_nil
    end

    it "parses response without status message" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200\r\n\r\n"))
      response.status_code.should eq(200)
      response.status_message.should eq("")
      response.headers.size.should eq(0)
      response.body.should eq("")
    end

    it "parses response with duplicated headers" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nWarning: 111 Revalidation failed\r\nWarning: 110 Response is stale\r\n\r\nhelloworld"))
      response.headers.get("Warning").should eq(["111 Revalidation failed", "110 Response is stale"])
    end

    it "parses response with cookies" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nSet-Cookie: a=b\r\nSet-Cookie: c=d\r\n\r\nhelloworld"))
      response.cookies["a"].value.should eq("b")
      response.cookies["c"].value.should eq("d")
    end

    it "parses response with chunked body" do
      response = Response.from_io(io = IO::Memory.new("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabcde\r\na\r\n0123456789\r\n0\r\n\r\n"))
      response.body.should eq("abcde0123456789")
      io.gets.should be_nil
    end

    it "parses response with streamed chunked body" do
      Response.from_io(io = IO::Memory.new("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabcde\r\na\r\n0123456789\r\n0\r\n\r\n")) do |response|
        response.body_io.gets_to_end.should eq("abcde0123456789")
        io.gets.should be_nil
      end
    end

    it "parses response with chunked body of size 0" do
      response = Response.from_io(io = IO::Memory.new("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n"))
      response.body.should eq("")
      io.gets.should be_nil
    end

    it "parses response ignoring body" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhelloworld"), true)
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(200)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("5")
      response.body.should eq("")
    end

    it "parses 204 response without body but Content-Length == 0 (#2512)" do
      response = Response.from_io(IO::Memory.new("HTTP/1.1 204 OK\r\nContent-Type: text/plain\r\nContent-Length: 0\r\n\r\n"))
      response.version.should eq("HTTP/1.1")
      response.status_code.should eq(204)
      response.status_message.should eq("OK")
      response.headers["content-type"].should eq("text/plain")
      response.headers["content-length"].should eq("0")
      response.body.should eq("")
    end

    it "parses long request lines" do
      request = Response.from_io?(IO::Memory.new("HTTP/1.1 200 #{"OK" * 16000}\r\n\r\n"))
      request.should eq(nil)
    end

    it "parses long headers" do
      request = Response.from_io?(IO::Memory.new("HTTP/1.1 200 OK\r\n#{"X-Test-Header: A pretty log header value\r\n" * 1000}\r\n"))
      request.should eq(nil)
    end

    it "doesn't sets content length for 1xx, 204 or 304" do
      [100, 101, 204, 304].each do |status|
        response = Response.new(status)
        response.headers.size.should eq(0)
      end
    end

    it "raises when creating 1xx, 204 or 304 with body" do
      [100, 101, 204, 304].each do |status|
        expect_raises ArgumentError do
          Response.new(status, "hello")
        end
      end
    end

    it "serialize with body" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "text/plain"
      headers["Content-Length"] = "5"

      response = Response.new(200, "hello", headers)
      io = IO::Memory.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhello")
    end

    it "serialize with body and cookies" do
      headers = HTTP::Headers.new
      headers["Content-Type"] = "text/plain"
      headers["Content-Length"] = "5"
      headers["Set-Cookie"] = "foo=bar; path=/"

      response = Response.new(200, "hello", headers)

      io = IO::Memory.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nSet-Cookie: foo=bar; path=/\r\n\r\nhello")

      response.cookies["foo"].value.should eq "bar" # Force lazy initialization

      io.clear
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nSet-Cookie: foo=bar; path=/\r\n\r\nhello")

      response.cookies["foo"] = "baz"
      response.cookies << Cookie.new("quux", "baz")

      io.clear
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\nSet-Cookie: foo=baz; path=/\r\nSet-Cookie: quux=baz; path=/\r\n\r\nhello")
    end

    it "sets content length from body" do
      response = Response.new(200, "hello")
      io = IO::Memory.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello")
    end

    it "sets content length even without body" do
      response = Response.new(200)
      io = IO::Memory.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
    end

    it "serialize as chunked with body_io" do
      response = Response.new(200, body_io: IO::Memory.new("hello"))
      io = IO::Memory.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n")
    end

    it "serialize as not chunked with body_io if HTTP/1.0" do
      response = Response.new(200, version: "HTTP/1.0", body_io: IO::Memory.new("hello"))
      io = IO::Memory.new
      response.to_io(io)
      io.to_s.should eq("HTTP/1.0 200 OK\r\nContent-Length: 5\r\n\r\nhello")
    end

    it "returns no content_type when header is missing" do
      response = Response.new(200, "")
      response.content_type.should be_nil
      response.charset.should be_nil
    end

    it "returns content type and no charset" do
      response = Response.new(200, "", headers: HTTP::Headers{"Content-Type" => "text/plain"})
      response.content_type.should eq("text/plain")
      response.charset.should be_nil
    end

    it "returns content type and charset, removes semicolon" do
      response = Response.new(200, "", headers: HTTP::Headers{"Content-Type" => "text/plain ; charset=UTF-8"})
      response.content_type.should eq("text/plain")
      response.charset.should eq("UTF-8")
    end

    it "returns content type and no charset, other parameter (#2520)" do
      response = Response.new(200, "", headers: HTTP::Headers{"Content-Type" => "text/plain ; colenc=U"})
      response.content_type.should eq("text/plain")
      response.charset.should be_nil
    end

    it "returns content type and charset, removes semicolon, with multiple parameters (#2520)" do
      response = Response.new(200, "", headers: HTTP::Headers{"Content-Type" => "text/plain ; colenc=U ; charset=UTF-8"})
      response.content_type.should eq("text/plain")
      response.charset.should eq("UTF-8")
    end

    it "creates Response with status code 204, no body and Content-Length == 0 (#2512)" do
      response = Response.new(204, version: "HTTP/1.0", body: "", headers: HTTP::Headers{"Content-Length" => "0"})
      response.status_code.should eq(204)
      response.body.should eq("")
    end

    describe "success?" do
      it "returns true for the 2xx" do
        response = Response.new(200)

        response.success?.should eq(true)
      end

      it "returns false for other ranges" do
        response = Response.new(500)

        response.success?.should eq(false)
      end
    end
  end
end
