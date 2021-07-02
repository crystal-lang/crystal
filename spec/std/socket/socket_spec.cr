require "./spec_helper"
require "../../support/tempfile"

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
    client_done = Channel(Nil).new
    server = Socket.new(Socket::Family::INET, Socket::Type::STREAM, Socket::Protocol::TCP)

    begin
      port = unused_local_port
      server.bind("0.0.0.0", port)
      server.listen

      spawn do
        TCPSocket.new("127.0.0.1", port).close
      ensure
        client_done.send nil
      end

      client = server.accept
      begin
        client.family.should eq(Socket::Family::INET)
        client.type.should eq(Socket::Type::STREAM)
        client.protocol.should eq(Socket::Protocol::TCP)
      ensure
        client.close
      end
    ensure
      server.close
      client_done.receive
    end
  end

  it "accept raises timeout error if read_timeout is specified" do
    server = Socket.new(Socket::Family::INET, Socket::Type::STREAM, Socket::Protocol::TCP)
    port = unused_local_port
    server.bind("0.0.0.0", port)
    server.read_timeout = 0.1
    server.listen

    expect_raises(IO::TimeoutError) { server.accept }
    expect_raises(IO::TimeoutError) { server.accept? }
  end

  it "sends messages" do
    port = unused_local_port
    server = Socket.tcp(Socket::Family::INET)
    server.bind("127.0.0.1", port)
    server.listen
    address = Socket::IPAddress.new("127.0.0.1", port)
    spawn do
      client = server.not_nil!.accept
      client.gets.should eq "foo"
      client.puts "bar"
    ensure
      client.try &.close
    end
    socket = Socket.tcp(Socket::Family::INET)
    socket.connect(address)
    socket.puts "foo"
    socket.gets.should eq "bar"
  ensure
    socket.try &.close
    server.try &.close
  end

  it "sends datagram over unix socket" do
    with_tempfile("datagram_unix") do |path|
      server = Socket.unix(Socket::Type::DGRAM)
      server.bind Socket::UNIXAddress.new(path)

      client = Socket.unix(Socket::Type::DGRAM)
      client.connect Socket::UNIXAddress.new(path)
      client.send "foo"

      message, _ = server.receive
      message.should eq "foo"
    end
  end

  describe "#bind" do
    each_ip_family do |family, _, any_address|
      it "binds to port" do
        socket = TCPSocket.new family
        socket.bind(any_address, 0)
        socket.listen

        address = socket.local_address.as(Socket::IPAddress)
        address.address.should eq(any_address)
        address.port.should be > 0
      ensure
        socket.try &.close
      end

      it "binds to port using Socket::IPAddress" do
        socket = TCPSocket.new family
        socket.bind Socket::IPAddress.new(any_address, 0)
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
