require "spec"
require "log/spec"
require "http/server/handler"
require "../../../../support/io"
require "../../../../support/retry"

describe HTTP::LogHandler do
  it "logs" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.remote_address = Socket::IPAddress.new("192.168.0.1", 1234)
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { called = true }
    logs = Log.capture("http.server") { handler.call(context) }
    logs.check(:info, %r(^192.168.0.1 - GET / HTTP/1.1 - 200 \(\d+(\.\d+)?[mµn]s\)$))
    called.should be_true
  end

  it "logs to custom logger" do
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)

    backend = Log::MemoryBackend.new
    log = Log.new("custom", backend, :info)
    handler = HTTP::LogHandler.new(log)
    handler.next = ->(ctx : HTTP::Server::Context) {}
    handler.call(context)

    logs = Log::EntriesChecker.new(backend.entries)
    logs.check(:info, %r(^- - GET / HTTP/1.1 - 200 \(\d+(\.\d+)?[mµn]s\)$))
  end

  it "log failed request" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { raise "foo" }
    logs = Log.capture("http.server") do
      expect_raises(Exception, "foo") do
        handler.call(context)
      end
    end
    logs.check(:info, %r(^- - GET / HTTP/1.1 - 200 \(\d+(\.\d+)?[mµn]s\)$))
  end
end
