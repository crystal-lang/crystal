require "spec"
require "http/server"

describe HTTP::WebSocketHandler do
  it "returns not found if the request is not an websocket upgrade" do
    io = IO::Memory.new
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    invoked = false
    handler = HTTP::WebSocketHandler.new { invoked = true }
    handler.next = HTTP::Handler::HandlerProc.new &.response.print("Hello")
    handler.call context

    response.close

    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
  end

  it "returns not found if the request Upgrade is invalid" do
    io = IO::Memory.new

    headers = HTTP::Headers{
      "Upgrade"               => "WS",
      "Connection"            => "Upgrade",
      "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Version" => "13",
    }
    request = HTTP::Request.new("GET", "/", headers: headers)
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    invoked = false
    handler = HTTP::WebSocketHandler.new { invoked = true }
    handler.next = HTTP::Handler::HandlerProc.new &.response.print("Hello")
    handler.call context

    response.close

    io.to_s.should eq("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
  end

  {% for connection in ["Upgrade", "keep-alive, Upgrade"] %}
    it "gives upgrade response for websocket upgrade request with '{{connection.id}}' request" do
      io = IO::Memory.new
      headers = HTTP::Headers{
        "Upgrade" =>           "websocket",
        "Connection" =>        {{connection}},
        "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
        "Sec-WebSocket-Version" => "13",
      }
      request = HTTP::Request.new("GET", "/", headers: headers)
      response = HTTP::Server::Response.new(io)
      context = HTTP::Server::Context.new(request, response)

      handler = HTTP::WebSocketHandler.new { }
      handler.next = HTTP::Handler::HandlerProc.new &.response.print("Hello")

      begin
        handler.call context
      rescue IO::Error
        # Raises because the IO::Memory is empty
      end

      response.close

      io.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n")
    end
  {% end %}

  it "gives upgrade response for case-insensitive 'WebSocket' upgrade request" do
    io = IO::Memory.new
    headers = HTTP::Headers{
      "Upgrade"               => "WebSocket",
      "Connection"            => "Upgrade",
      "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Version" => "13",
    }
    request = HTTP::Request.new("GET", "/", headers: headers)
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::WebSocketHandler.new { }
    handler.next = HTTP::Handler::HandlerProc.new &.response.print("Hello")

    begin
      handler.call context
    rescue IO::Error
      # Raises because the IO::Memory is empty
    end

    response.close

    io.to_s.should eq("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n\r\n")
  end

  it "returns bad request if Sec-WebSocket-Key is missing" do
    io = IO::Memory.new

    headers = HTTP::Headers{
      "Upgrade"               => "websocket",
      "Connection"            => "Upgrade",
      "Sec-WebSocket-Version" => "13",
    }
    request = HTTP::Request.new("GET", "/", headers: headers)
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::WebSocketHandler.new { }
    handler.call context

    response.close

    io.to_s.should eq("HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain\r\nContent-Length: 16\r\n\r\n400 Bad Request\n")
  end

  it "returns upgrade required if Sec-WebSocket-Version is missing" do
    io = IO::Memory.new

    headers = HTTP::Headers{
      "Upgrade"           => "websocket",
      "Connection"        => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
    }
    request = HTTP::Request.new("GET", "/", headers: headers)
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::WebSocketHandler.new { }
    handler.call context

    response.close

    io.to_s.should eq("HTTP/1.1 426 Upgrade Required\r\nSec-WebSocket-Version: 13\r\nContent-Length: 0\r\n\r\n")
  end

  it "returns upgrade required if Sec-WebSocket-Version is invalid" do
    io = IO::Memory.new

    headers = HTTP::Headers{
      "Upgrade"               => "websocket",
      "Connection"            => "Upgrade",
      "Sec-WebSocket-Key"     => "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Version" => "12",
    }
    request = HTTP::Request.new("GET", "/", headers: headers)
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)

    handler = HTTP::WebSocketHandler.new { }
    handler.call context

    response.close

    io.to_s.should eq("HTTP/1.1 426 Upgrade Required\r\nSec-WebSocket-Version: 13\r\nContent-Length: 0\r\n\r\n")
  end
end
