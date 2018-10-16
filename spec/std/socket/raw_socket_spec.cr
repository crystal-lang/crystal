require "./spec_helper"

describe Socket::Raw do
  it "creates a unix socket" do
    sock = Socket::Raw.new(Socket::Family::UNIX, Socket::Type::STREAM)
    sock.should be_a(Socket::Raw)
    sock.family.should eq(Socket::Family::UNIX)
    sock.type.should eq(Socket::Type::STREAM)

    sock = Socket::Raw.new(Socket::Family::UNIX, Socket::Type::DGRAM)
    sock.type.should eq(Socket::Type::DGRAM)
  end

  it ".accept" do
    server = Socket::Raw.new(Socket::Family::INET, Socket::Type::STREAM, Socket::Protocol::TCP)
    port = unused_local_port
    server.bind("0.0.0.0", port)
    server.listen

    spawn { TCPSocket.new("127.0.0.1", port).close }

    client = server.accept
    client.family.should eq(Socket::Family::INET)
    client.type.should eq(Socket::Type::STREAM)
    client.protocol.should eq(Socket::Protocol::TCP)
  end

  it "sends messages" do
    server = Socket::Raw.new(Socket::Family::INET6, Socket::Type::STREAM)
    server.bind("::1", 0)
    server.listen
    address = server.local_address(Socket::IPAddress)
    spawn do
      client = server.not_nil!.accept
      client.gets.should eq "foo"
      client.puts "bar"
    ensure
      client.try &.close
    end
    socket = Socket::Raw.new(Socket::Family::INET6, Socket::Type::STREAM)
    socket.connect(address)
    socket.puts "foo"
    socket.gets.should eq "bar"
  ensure
    socket.try &.close
    server.try &.close
  end

  describe "#bind" do
    each_ip_family do |family, _, any_address|
      it "binds to port" do
        socket = Socket::Raw.new family, Socket::Type::STREAM
        socket.bind(any_address, 0)
        socket.listen

        address = socket.local_address.as(Socket::IPAddress)
        address.address.should eq(any_address)
        address.port.should be > 0
      ensure
        socket.try &.close
      end
    end
  end
end
