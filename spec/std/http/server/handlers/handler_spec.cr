require "spec"
require "http/server/handler"

private class EmptyHTTPHandler
  include HTTP::Handler

  def call(context)
    call_next(context)
  end
end

describe HTTP::Handler do
  it "responds with not found if there's no next handler" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = EmptyHTTPHandler.new
    handler.call(context)
    response.close

    io.rewind
    response = HTTP::Client::Response.from_io(io)
    response.status_code.should eq(404)
    response.body.should eq("404 Not Found\n")
  end
end
