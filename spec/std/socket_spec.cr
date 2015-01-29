require "spec"
require "socket"

describe "UNIXSocket" do
  it "sends and receives messages" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      UNIXSocket.open(path) do |client|
        server.accept do |sock|
          client << "ping"
          sock.read(4).should eq("ping")
          sock << "pong"
          client.read(4).should eq("pong")
        end
      end
    end
  end

  it "creates a pair of sockets" do
    UNIXSocket.pair("/tmp/sock") do |left, right|
      left << "ping"
      right.read(4).should eq("ping")
      right << "pong"
      left.read(4).should eq("pong")
    end
  end
end

describe "TCPSocket" do
  it "sends and receives messages" do
    TCPServer.open("::", 12345) do |server|
      TCPSocket.open("localhost", 12345) do |client|
        sock = server.accept
        client << "ping"
        sock.read(4).should eq("ping")
        sock << "pong"
        client.read(4).should eq("pong")
      end
    end
  end
end

describe "UDPSocket" do
  it "sends and receives messages" do
    server = UDPSocket.new(LibC::AF_INET6)
    server.bind("::", 12346)

    client = UDPSocket.new(LibC::AF_INET)
    client.connect("localhost", 12346)

    client << "message"
    server.read(7).should eq("message")

    client.close
    server.close
  end
end
