require "./spec_helper"
require "socket"

describe UDPSocket do
  it "creates a raw socket" do
    sock = UDPSocket.new
    sock.family.should eq(Socket::Family::INET)

    sock = UDPSocket.new(Socket::Family::INET6)
    sock.family.should eq(Socket::Family::INET6)
  end

  it "reads and writes data to server" do
    port = unused_local_port

    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::", port)
    server.local_address.should eq(Socket::IPAddress.new("::", port))

    client = UDPSocket.new(Socket::Family::INET6)
    client.connect("::1", port)
    client.local_address.family.should eq(Socket::Family::INET6)
    client.local_address.address.should eq("::1")
    client.remote_address.should eq(Socket::IPAddress.new("::1", port))

    client << "message"
    server.gets(7).should eq("message")

    client.close
    server.close
  end

  it "sends and receives messages over IPv4" do
    buffer = uninitialized UInt8[256]

    server = UDPSocket.new(Socket::Family::INET)
    server.bind("127.0.0.1", 0)

    client = UDPSocket.new(Socket::Family::INET)
    client.send("message equal to buffer", server.local_address)

    bytes_read, client_addr = server.receive(buffer.to_slice[0, 23])
    message = String.new(buffer.to_slice[0, bytes_read])
    message.should eq("message equal to buffer")
    client_addr.should eq(Socket::IPAddress.new("127.0.0.1", client.local_address.port))

    client.send("message less than buffer", server.local_address)

    bytes_read, client_addr = server.receive(buffer.to_slice)
    message = String.new(buffer.to_slice[0, bytes_read])
    message.should eq("message less than buffer")

    client.connect server.local_address
    client.send "ip4 message"

    message, client_addr = server.receive
    message.should eq("ip4 message")
    client_addr.should eq(Socket::IPAddress.new("127.0.0.1", client.local_address.port))

    server.close
    client.close
  end

  it "sends and receives messages over IPv6" do
    buffer = uninitialized UInt8[1500]

    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::1", 0)

    client = UDPSocket.new(Socket::Family::INET6)
    client.send("some message", server.local_address)

    bytes_read, client_addr = server.receive(buffer.to_slice)
    String.new(buffer.to_slice[0, bytes_read]).should eq("some message")
    client_addr.should eq(Socket::IPAddress.new("::1", client.local_address.port))

    client.connect server.local_address
    client.send "ip6 message"

    message, client_addr = server.receive(20)
    message.should eq("ip6 message")
    client_addr.should eq(Socket::IPAddress.new("::1", client.local_address.port))

    server.close
    client.close
  end

  it "broadcasts messages" do
    port = unused_local_port

    client = UDPSocket.new(Socket::Family::INET)
    client.broadcast = true
    client.broadcast?.should be_true
    client.connect("255.255.255.255", port)
    client.send("broadcast").should eq(9)
    client.close
  end
end
