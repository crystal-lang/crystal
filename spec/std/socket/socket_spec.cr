require "./spec_helper"

describe Socket do
  describe ".unix" do
    it "creates a unix socket" do
      sock = Socket.unix
      sock.should be_a(Socket)
      sock.family.should eq(Socket::Family::UNIX)
      sock.type.should eq(Socket::Type::STREAM)

      sock = Socket.unix(Socket::Type::DGRAM)
      sock.type.should eq(Socket::Type::DGRAM)
    end
  end

  it ".accept" do
    server = Socket.new(Socket::Family::INET, Socket::Type::STREAM, Socket::Protocol::TCP)
    port = unused_local_port
    server.bind("0.0.0.0", port)
    server.listen

    spawn { TCPSocket.new("127.0.0.1", port).close }

    client = server.accept
    client.family.should eq(Socket::Family::INET)
    client.type.should eq(Socket::Type::STREAM)
    client.protocol.should eq(Socket::Protocol::TCP)
  end
end
