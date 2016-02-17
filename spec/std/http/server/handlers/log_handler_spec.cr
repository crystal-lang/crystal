require "spec"
require "http/server"

describe HTTP::LogHandler do
  it "logs" do
    io = MemoryIO.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    log_io = MemoryIO.new
    handler = HTTP::LogHandler.new(log_io)
    handler.next = ->(ctx : HTTP::Server::Context) { called = true }
    handler.call(context)
    (log_io.to_s =~ %r(GET / - 200 \(\d.+\))).should be_truthy
    called.should be_true
  end
end
