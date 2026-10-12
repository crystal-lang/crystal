{% skip_file unless Fiber.has_constant?(:ExecutionContext) %}
require "spec"
require "socket"

describe Fiber::ExecutionContext::Isolated do
  it "waits to read after a write on the same socket" do
    server = TCPServer.new("127.0.0.1", 0)
    client = TCPSocket.new("127.0.0.1", server.local_address.port)
    peer = server.accept
    replies = 0

    ctx = Fiber::ExecutionContext::Isolated.new("request-reply") do
      buf = Bytes.new(4)
      20.times do
        client.write "ping".to_slice
        client.read_fully(buf)
        replies += 1 if String.new(buf) == "pong"
      end
    end

    buf = Bytes.new(4)
    20.times do
      peer.read_fully(buf)
      sleep 1.millisecond # let the isolated fiber wait for the reply
      peer.write "pong".to_slice
    end

    ctx.wait
    replies.should eq(20)
  ensure
    peer.try &.close
    client.try &.close
    server.try &.close
  end
end
