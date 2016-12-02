require "spec"
require "http/server"

describe HTTP::LogHandler do
  it "logs" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    log_io = IO::Memory.new
    handler = HTTP::LogHandler.new(log_io)
    handler.next = ->(ctx : HTTP::Server::Context) { called = true }
    handler.call(context)
    (log_io.to_s =~ %r(GET / - 200 \(\d.+\))).should be_truthy
    called.should be_true
  end

  it "does log errors" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    log_io = IO::Memory.new
    handler = HTTP::LogHandler.new(log_io)
    handler.next = ->(ctx : HTTP::Server::Context) { raise "foo" }
    expect_raises do
      handler.call(context)
    end
    (log_io.to_s =~ %r(GET / - Unhandled exception:)).should be_truthy
  end
end
