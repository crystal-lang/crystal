require "spec"
require "http/server/response"
require "http/headers"
require "http/status"
require "http/cookie"

private alias Response = HTTP::Server::Response

private class ReverseResponseOutput < IO
  @output : IO

  def initialize(@output : IO)
  end

  def write(slice : Bytes) : Nil
    slice.reverse_each do |byte|
      @output.write_byte(byte)
    end
  end

  def read(slice : Bytes)
    raise "Not implemented"
  end

  def close
    @output.close
  end

  def flush
    @output.flush
  end
end

describe HTTP::Server::Response do
  it "closes" do
    io = IO::Memory.new
    response = Response.new(io)
    response.close
    response.closed?.should be_true
    io.closed?.should be_false
    expect_raises(IO::Error, "Closed stream") { response << "foo" }
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
  end

  it "does not automatically add the `content-length` header if the response is a 304" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :not_modified
    response.close
    io.to_s.should eq("HTTP/1.1 304 Not Modified\r\n\r\n")
  end

  it "does not automatically add the `content-length` header if the response is a 204" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :no_content
    response.close
    io.to_s.should eq("HTTP/1.1 204 No Content\r\n\r\n")
  end

  it "does not automatically add the `content-length` header if the response is informational" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :processing
    response.close
    io.to_s.should eq("HTTP/1.1 102 Processing\r\n\r\n")
  end

  # Case where the content-length represents the size of the data that would have been returned.
  it "allows specifying the content-length header explicitly" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :not_modified
    response.headers["Content-Length"] = "5"
    response.close
    io.to_s.should eq("HTTP/1.1 304 Not Modified\r\nContent-Length: 5\r\n\r\n")
  end

  it "allow explicitly configuring a `Transfer-Encoding` response" do
    io = IO::Memory.new
    response = Response.new(io)
    response.headers["Transfer-Encoding"] = "chunked"
    response.print "Hello"
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n0\r\n\r\n")
  end

  it "prints less then buffer's size" do
    io = IO::Memory.new
    response = Response.new(io)
    response.print("Hello")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
  end

  it "prints less then buffer's size to output" do
    io = IO::Memory.new
    response = Response.new(io)
    response.output.print("Hello")
    response.output.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
  end

  it "prints more then buffer's size" do
    io = IO::Memory.new
    response = Response.new(io)
    str = "1234567890"
    slices = (IO::DEFAULT_BUFFER_SIZE // 10)
    slices.times do
      response.print(str)
    end
    response.print(str)
    response.close
    first_chunk = str * slices
    second_chunk = str
    io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n#{(first_chunk.bytesize).to_s(16)}\r\n#{first_chunk}\r\n#{(second_chunk.bytesize).to_s(16)}\r\n#{second_chunk}\r\n0\r\n\r\n")
  end

  it "prints with content length" do
    io = IO::Memory.new
    response = Response.new(io)
    response.headers["Content-Length"] = "10"
    response.print("1234")
    response.print("567890")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n1234567890")
  end

  it "prints with content length (method)" do
    io = IO::Memory.new
    response = Response.new(io)
    response.content_length = 10
    response.print("1234")
    response.print("567890")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n1234567890")
  end

  it "doesn't override content-length when there's no body" do
    io = IO::Memory.new
    response = Response.new(io)
    response.content_length = 10
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\n")
  end

  it "adds header" do
    io = IO::Memory.new
    response = Response.new(io)
    response.headers["Content-Type"] = "text/plain"
    response.print("Hello")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
  end

  it "sets content type" do
    io = IO::Memory.new
    response = Response.new(io)
    response.content_type = "text/plain"
    response.print("Hello")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nHello")
  end

  it "sets content type after headers sent" do
    io = IO::Memory.new
    response = Response.new(io)
    response.print("Hello")
    response.flush
    expect_raises(IO::Error, "Headers already sent") do
      response.content_type = "text/plain"
    end
  end

  it "sets status code" do
    io = IO::Memory.new
    response = Response.new(io)
    return_value = response.status_code = 201
    return_value.should eq 201
    response.status.should eq HTTP::Status::CREATED
    response.status_message.should eq "Created"
    response.print("Hello")
    response.flush
    expect_raises(IO::Error, "Headers already sent") do
      response.status_code = 201
    end
  end

  it "retrieves status code" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :created
    response.status_code.should eq 201
  end

  it "changes status message" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :not_found
    response.status_message = "Custom status"
    response.close
    io.to_s.should eq("HTTP/1.1 404 Custom status\r\nContent-Length: 0\r\n\r\n")
    response.status_message.should eq "Custom status"

    expect_raises(IO::Error, "Closed stream") do
      response.status_message = "Other status"
    end
  end

  it "changes status and others" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :not_found
    response.version = "HTTP/1.0"
    response.close
    io.to_s.should eq("HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n")
  end

  it "changes status and others after headers sent" do
    io = IO::Memory.new
    response = Response.new(io)
    response.print("Foo")
    response.flush
    expect_raises(IO::Error, "Headers already sent") do
      response.status = :not_found
    end
    expect_raises(IO::Error, "Headers already sent") do
      response.version = "HTTP/1.0"
    end
  end

  it "closes gracefully with replaced output that syncs close (#11389)" do
    output = IO::Memory.new
    response = HTTP::Server::Response.new(output)

    response.output = IO::Stapled.new(response.output, response.output, sync_close: true)
    response.print "some body"

    response.close

    output.rewind.gets_to_end.should eq "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nsome body"
  end

  it "flushes" do
    io = IO::Memory.new
    response = Response.new(io)
    response.print("Hello")
    response.flush
    io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nHello\r\n0\r\n\r\n")
  end

  it "wraps output" do
    io = IO::Memory.new
    response = Response.new(io)
    response.output = ReverseResponseOutput.new(response.output)
    response.print("1234")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\n4321")
  end

  it "writes and flushes with HTTP 1.0" do
    io = IO::Memory.new
    response = Response.new(io, "HTTP/1.0")
    response.print("1234")
    response.flush
    io.to_s.should eq("HTTP/1.0 200 OK\r\n\r\n1234")
  end

  it "resets and clears headers and cookies" do
    io = IO::Memory.new
    response = Response.new(io)
    response.headers["Foo"] = "Bar"
    response.cookies["Bar"] = "Foo"
    response.status = HTTP::Status::USE_PROXY
    response.status_message = "Baz"
    response.reset
    response.headers.should be_empty
    response.cookies.should be_empty
    response.status.should eq HTTP::Status::OK
    response.status_message.should eq "OK"
  end

  it "writes cookie headers" do
    io = IO::Memory.new
    response = Response.new(io)
    response.cookies["Bar"] = "Foo"
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nSet-Cookie: Bar=Foo\r\n\r\n")

    io = IO::Memory.new
    response = Response.new(io)
    response.cookies["Bar"] = "Foo"
    response.print("Hello")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nSet-Cookie: Bar=Foo\r\n\r\nHello")
  end

  it "closes when it fails to write" do
    io = IO::Memory.new
    response = Response.new(io)
    response.print("Hello")
    response.flush
    io.close
    response.print("Hello")
    expect_raises(HTTP::Server::ClientError) { response.flush }
    response.closed?.should be_true
  end

  describe "#respond_with_status" do
    it "uses default values" do
      io = IO::Memory.new
      response = Response.new(io)
      response.content_type = "text/html"
      response.respond_with_status(500)
      io.to_s.should eq("HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nContent-Length: 26\r\n\r\n500 Internal Server Error\n")
      response.status_message.should eq "Internal Server Error"
    end

    it "sends custom code and message" do
      io = IO::Memory.new
      response = Response.new(io)
      response.respond_with_status(400, "Request Error")
      io.to_s.should eq("HTTP/1.1 400 Request Error\r\nContent-Type: text/plain\r\nContent-Length: 18\r\n\r\n400 Request Error\n")
      response.status_message.should eq "Request Error"
    end

    it "sends HTTP::Status" do
      io = IO::Memory.new
      response = Response.new(io)
      response.respond_with_status(HTTP::Status::URI_TOO_LONG)
      io.to_s.should eq("HTTP/1.1 414 URI Too Long\r\nContent-Type: text/plain\r\nContent-Length: 17\r\n\r\n414 URI Too Long\n")
      response.status_message.should eq "URI Too Long"
    end

    it "sends HTTP::Status and custom message" do
      io = IO::Memory.new
      response = Response.new(io)
      response.respond_with_status(HTTP::Status::URI_TOO_LONG, "Request Error")
      io.to_s.should eq("HTTP/1.1 414 Request Error\r\nContent-Type: text/plain\r\nContent-Length: 18\r\n\r\n414 Request Error\n")
      response.status_message.should eq "Request Error"
    end

    it "raises when response is closed" do
      io = IO::Memory.new
      response = Response.new(io)
      response.close
      expect_raises(IO::Error, "Closed stream") do
        response.respond_with_status(400)
      end
    end

    it "raises when headers written" do
      io = IO::Memory.new
      response = Response.new(io)
      response.print("Hello")
      response.flush
      expect_raises(IO::Error, "Headers already sent") do
        response.respond_with_status(400)
      end
    end
  end

  describe "#redirect" do
    ["/path", URI.parse("/path")].each do |location|
      it "#{location.class} location" do
        io = IO::Memory.new
        response = Response.new(io)
        response.redirect(location)
        io.to_s.should eq("HTTP/1.1 302 Found\r\nLocation: /path\r\nContent-Length: 0\r\n\r\n")
      end
    end

    it "encodes special characters" do
      io = IO::Memory.new
      response = Response.new(io)
      response.redirect("https://example.com/path\nfoo bar")
      io.to_s.should eq("HTTP/1.1 302 Found\r\nLocation: https://example.com/path%0Afoo%20bar\r\nContent-Length: 0\r\n\r\n")
    end

    it "doesn't encode URIs twice" do
      io = IO::Memory.new
      response = Response.new(io)
      u = URI.new "https", host: "example.com", path: "auth",
        query: URI::Params.new({"redirect_uri" => ["http://example.com/callback"]})
      response.redirect(u)
      io.to_s.should eq("HTTP/1.1 302 Found\r\nLocation: https://example.com/auth?redirect_uri=http%3A%2F%2Fexample.com%2Fcallback\r\nContent-Length: 0\r\n\r\n")
    end

    it "permanent redirect" do
      io = IO::Memory.new
      response = Response.new(io)
      response.redirect("/path", status: :moved_permanently)
      io.to_s.should eq("HTTP/1.1 301 Moved Permanently\r\nLocation: /path\r\nContent-Length: 0\r\n\r\n")
    end

    it "with header" do
      io = IO::Memory.new
      response = Response.new(io)
      response.headers["Foo"] = "Bar"
      response.redirect("/path", status: :moved_permanently)
      io.to_s.should eq("HTTP/1.1 301 Moved Permanently\r\nFoo: Bar\r\nLocation: /path\r\nContent-Length: 0\r\n\r\n")
    end

    it "fails if headers already sent" do
      io = IO::Memory.new
      response = Response.new(io)
      response.puts "foo"
      response.flush
      expect_raises(IO::Error, "Headers already sent") do
        response.redirect("/path")
      end
    end

    it "fails if closed" do
      io = IO::Memory.new
      response = Response.new(io)
      response.close
      expect_raises(IO::Error, "Closed stream") do
        response.redirect("/path")
      end
    end
  end
end
