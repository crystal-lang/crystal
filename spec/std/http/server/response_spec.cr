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
    1000.times do
      response.print(str)
    end
    response.close
    first_chunk = str * 819
    second_chunk = str * 181
    io.to_s.should eq("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1ffe\r\n#{first_chunk}\r\n712\r\n#{second_chunk}\r\n0\r\n\r\n")
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

  it "sets status code" do
    io = IO::Memory.new
    response = Response.new(io)
    return_value = response.status_code = 201
    return_value.should eq 201
    response.status.should eq HTTP::Status::CREATED
  end

  it "retrieves status code" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :created
    response.status_code.should eq 201
  end

  it "changes status and others" do
    io = IO::Memory.new
    response = Response.new(io)
    response.status = :not_found
    response.version = "HTTP/1.0"
    response.close
    io.to_s.should eq("HTTP/1.0 404 Not Found\r\nContent-Length: 0\r\n\r\n")
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
    response.reset
    response.headers.empty?.should be_true
    response.cookies.empty?.should be_true
  end

  it "writes cookie headers" do
    io = IO::Memory.new
    response = Response.new(io)
    response.cookies["Bar"] = "Foo"
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nSet-Cookie: Bar=Foo; path=/\r\n\r\n")

    io = IO::Memory.new
    response = Response.new(io)
    response.cookies["Bar"] = "Foo"
    response.print("Hello")
    response.close
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\nSet-Cookie: Bar=Foo; path=/\r\n\r\nHello")
  end

  it "responds with an error" do
    io = IO::Memory.new
    response = Response.new(io)
    response.content_type = "text/html"
    response.respond_with_error
    io.to_s.should eq("HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n1a\r\n500 Internal Server Error\n\r\n")

    io = IO::Memory.new
    response = Response.new(io)
    response.respond_with_error("Bad Request", 400)
    io.to_s.should eq("HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nTransfer-Encoding: chunked\r\n\r\n10\r\n400 Bad Request\n\r\n")
  end
end
