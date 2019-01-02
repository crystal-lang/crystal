require "spec"
require "http/server"

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
end
