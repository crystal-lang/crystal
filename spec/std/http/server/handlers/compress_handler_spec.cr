require "spec"
require "http/server"

describe HTTP::CompressHandler do
  it "doesn't deflates if doesn't have 'deflate' in Accept-Encoding header" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::CompressHandler.new
    handler.next = HTTP::Handler::HandlerProc.new do |ctx|
      ctx.response.print "Hello"
    end
    handler.call(context)
    response.close

    io.rewind
    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
  end

  it "deflates if has deflate in 'deflate' Accept-Encoding header" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.headers["Accept-Encoding"] = "foo, deflate, other"

    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::CompressHandler.new
    handler.next = HTTP::Handler::HandlerProc.new do |ctx|
      ctx.response.print "Hello"
    end
    handler.call(context)
    response.close

    io.rewind
    response2 = HTTP::Client::Response.from_io(io, decompress: false)
    body = response2.body

    io2 = IO::Memory.new(body)
    flate = Flate::Reader.new(io2)
    flate.gets_to_end.should eq("Hello")
  end

  it "deflates gzip if has deflate in 'deflate' Accept-Encoding header" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.headers["Accept-Encoding"] = "foo, gzip, other"

    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::CompressHandler.new
    handler.next = HTTP::Handler::HandlerProc.new do |ctx|
      ctx.response.print "Hello"
    end
    handler.call(context)
    response.close

    io.rewind
    response2 = HTTP::Client::Response.from_io(io, decompress: false)
    body = response2.body

    io2 = IO::Memory.new(body)
    gzip = Gzip::Reader.new(io2)
    gzip.gets_to_end.should eq("Hello")
  end
end
