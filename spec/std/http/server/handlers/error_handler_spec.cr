require "spec"
require "http/server/handler"
require "../../../../support/log"
require "../../../../support/io"

describe HTTP::ErrorHandler do
  it "rescues from exception" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    exception = Exception.new("OH NO!")
    handler = HTTP::ErrorHandler.new(verbose: true)
    handler.next = ->(ctx : HTTP::Server::Context) { raise exception }
    logs = capture_logs("http.server") { handler.call(context) }
    response.close

    client_response = HTTP::Client::Response.from_io(io.rewind)
    client_response.status_code.should eq(500)
    client_response.status_message.should eq("Internal Server Error")
    client_response.headers["content-type"].should eq("text/plain")
    client_response.headers.has_key?("content-length").should be_true
    client_response.body.should match(/^ERROR: OH NO! \(Exception\)/)

    match_logs(logs,
      {:error, "Unhandled exception", exception}
    )
  end

  it "logs to custom logger" do
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)

    exception = Exception.new("OH NO!")
    backend = Log::MemoryBackend.new
    log = Log.new("custom", backend, :info)
    handler = HTTP::ErrorHandler.new(log: log)
    handler.next = ->(ctx : HTTP::Server::Context) { raise exception }
    handler.call(context)

    match_logs(backend.entries,
      {:error, "Unhandled exception", exception}
    )
  end

  it "can return a generic error message" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    exception = Exception.new("OH NO!")
    handler = HTTP::ErrorHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { raise exception }
    logs = capture_logs("http.server") { handler.call(context) }

    client_response = HTTP::Client::Response.from_io(io.rewind)
    client_response.status_code.should eq(500)
    client_response.status_message.should eq("Internal Server Error")
    client_response.headers["content-type"].should eq("text/plain")
    client_response.body.should eq("500 Internal Server Error\n")

    match_logs(logs,
      {:error, "Unhandled exception", exception}
    )
  end

  it "log debug message when the output is closed" do
    io = IO::Memory.new
    io.close
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::ErrorHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) { ctx.response.print "Hi!"; ctx.response.flush }
    logs = capture_logs("http.server") { handler.call(context) }

    match_logs(logs,
      {:debug, "Error while writing data to the client"}
    )
    logs[0].exception.should be_a(IO::Error)
  end

  it "doesn't write errors when there is some output already sent" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    exception = Exception.new("OH NO!")
    handler = HTTP::ErrorHandler.new
    handler.next = ->(ctx : HTTP::Server::Context) do
      ctx.response.print "Hi"
      ctx.response.flush
      raise exception
    end
    logs = capture_logs("http.server") { handler.call(context) }
    response.close

    client_response = HTTP::Client::Response.from_io(io.rewind)
    client_response.status_code.should eq(200)
    client_response.status_message.should eq("OK")
    client_response.body.should eq("Hi")

    match_logs(logs,
      {:error, "Unhandled exception", exception}
    )
  end
end
