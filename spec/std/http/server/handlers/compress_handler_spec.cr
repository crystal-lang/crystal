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
    flate = Compress::Deflate::Reader.new(io2)
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
    gzip = Compress::Gzip::Reader.new(io2)
    gzip.gets_to_end.should eq("Hello")
  end

  it "doesn't compress twice" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.headers["Accept-Encoding"] = "gzip"

    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler1 = HTTP::CompressHandler.new
    handler2 = HTTP::CompressHandler.new
    handler1.next = handler2
    handler2.next = HTTP::Handler::HandlerProc.new do |ctx|
      ctx.response.print "Hello"
    end
    handler1.call(context)
    response.close

    io.rewind
    response2 = HTTP::Client::Response.from_io(io)
    response2.body.should eq("Hello")
  end

  it "fix content-length header" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.headers["Accept-Encoding"] = "gzip"

    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::CompressHandler.new
    handler.next = HTTP::Handler::HandlerProc.new do |ctx|
      ctx.response.content_length = 5
      ctx.response.print "Hello"
      ctx.response.flush
    end
    handler.call(context)
    response.close

    io.rewind
    response = HTTP::Client::Response.from_io(io)
    response.body.should eq("Hello")
  end

  it "don't try to compress for empty body responses" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.headers["Accept-Encoding"] = "gzip"

    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::CompressHandler.new
    handler.next = HTTP::Handler::HandlerProc.new do |ctx|
      context.response.status = :not_modified
    end
    handler.call(context)
    response.close

    io.rewind
    io.to_s.should eq("HTTP/1.1 304 Not Modified\r\n\r\n")
  end

  it "don't try to compress upgraded response" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.headers["Accept-Encoding"] = "gzip"

    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::CompressHandler.new
    handler.next = HTTP::Handler::HandlerProc.new do |ctx|
      response.status = :switching_protocols
      response.upgrade do |io|
      end
    end
    handler.call(context)
    response.close

    io.rewind
    io.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\n\r\n")
  end
end
