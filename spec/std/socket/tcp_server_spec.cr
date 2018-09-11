require "./spec_helper"
require "socket"

describe TCPServer do
  it "creates a raw socket" do
    sock = TCPServer.new
    sock.family.should eq(Socket::Family::INET)

    sock = TCPServer.new(Socket::Family::INET6)
    sock.family.should eq(Socket::Family::INET6)
  end

  it "fails when port is in use" do
    port = unused_local_port

    expect_raises Errno, /(already|Address) in use/ do
      sock = Socket.tcp(Socket::Family::INET6)
      sock.bind(Socket::IPAddress.new("::1", port))

      TCPServer.open("::1", port) { }
    end
  end

  it "doesn't reuse the TCP port by default (SO_REUSEPORT)" do
    TCPServer.open("::", 0) do |server|
      expect_raises(Errno) do
        TCPServer.open("::", server.local_address.port) { }
      end
    end
  end

  it "reuses the TCP port (SO_REUSEPORT)" do
    TCPServer.open("::", 0, reuse_port: true) do |server|
      TCPServer.open("::", server.local_address.port, reuse_port: true) { }
    end
  end
end
