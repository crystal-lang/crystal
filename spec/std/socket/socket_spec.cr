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

  it "#close_on_exec?" do
    socket = Socket.tcp(Socket::Family::INET)
    socket.close_on_exec?.should be_false
    socket.close_on_exec = true
    socket.close_on_exec?.should be_true
    socket.close_on_exec = false
    socket.close_on_exec?.should be_false
  ensure
    socket.try &.close
  end

  it "#blocking?" do
    socket = Socket.tcp(Socket::Family::INET)
    socket.blocking.should be_false
    socket.blocking = true
    socket.blocking.should be_true
    socket.blocking = false
    socket.blocking.should be_false
  ensure
    socket.try &.close
  end

  it "#tty?" do
    Socket.tcp(Socket::Family::INET).tty?.should be_false
  end
end
