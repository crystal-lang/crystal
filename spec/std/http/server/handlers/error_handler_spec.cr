require "spec"
require "http/server/handler"
require "../../../../support/io"

describe HTTP::ErrorHandler do
  it "rescues from exception" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::ErrorHandler.new(verbose: true)
    handler.next = ->(ctx : HTTP::Server::Context) { raise "OH NO!" }
    handler.call(context)

    response.close

    io.rewind
    response2 = HTTP::Client::Response.from_io(io)
    response2.status_code.should eq(500)
    response2.status_message.should eq("Internal Server Error")
    (response2.body =~ /ERROR: OH NO!/).should be_truthy
  end

  it "can return a generic error message" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::ErrorHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { raise "OH NO!" }
    handler.call(context)
    io.to_s.match(/500 Internal Server Error/).should_not be_nil
    io.to_s.match(/OH NO/).should be_nil
  end

  it "doesn't write errors when the output is closed" do
    io = RaiseIOError.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::ErrorHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { ctx.response.flush }
    handler.call(context)
  end

  it "doesn't write errors when there is some output already sent" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::ErrorHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) do
      ctx.response.print "Hi"
      ctx.response.flush
      raise "OH NO!"
    end
    handler.call(context)
    io.to_s.should_not match(/500 Internal Server Error/)
  end
end
