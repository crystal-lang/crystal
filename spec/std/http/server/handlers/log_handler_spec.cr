require "spec"
require "http/server/handler"
require "../../../../support/log"
require "../../../../support/io"

describe HTTP::LogHandler do
  it "logs" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    request.remote_address = "192.168.0.1"
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    called = false
    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { called = true }
    logs = capture_logs("http.server") { handler.call(context) }
    match_logs(logs,
      {:info, %r(^192.168.0.1 - GET / HTTP/1.1 - 200 \(\d+(\.\d+)?[mµn]s\)$)}
    )
    called.should be_true
  end

  it "log failed request" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::LogHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { raise "foo" }
    logs = capture_logs("http.server") do
      expect_raises(Exception, "foo") do
        handler.call(context)
      end
    end
    match_logs(logs,
      {:info, %r(^- - GET / HTTP/1.1 - 200 \(\d+(\.\d+)?[mµn]s\)$)}
    )
  end
end
