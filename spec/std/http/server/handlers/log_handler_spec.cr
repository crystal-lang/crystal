require "spec"
require "http/server/handler"
require "../../../../support/log"
require "../../../../support/io"

describe HTTP::LogHandler do
  it "logs" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { called = true }
    log = capture_log("http.server") { handler.call(context) }
    log[0].severity.should eq(Log::Severity::Info)
    log[0].message.should match %r(GET / - 200 \(\d+(\.\d+)?[mµn]s\))
    called.should be_true
  end

  it "does log errors" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { raise "foo" }
    log = capture_log("http.server") do
      expect_raises(Exception, "foo") do
        handler.call(context)
      end
    end
    log[0].severity.should eq(Log::Severity::Error)
    log[0].message.should match %r(GET / - Unhandled exception:)
  end

  it "doesn't log error when the response has been closed" do
    io = RaiseIOError.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { ctx.response.flush }
    log = capture_log("http.server") { handler.call(context) rescue nil }
    log.should be_empty
  end
end
