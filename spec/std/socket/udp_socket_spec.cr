require "./spec_helper"
require "socket"

describe UDPSocket do
  each_ip_family do |family, address|
    it "#bind" do
      port = unused_local_port
      socket = UDPSocket.new(family)
      socket.bind(address, port)
      socket.local_address.should eq(Socket::IPAddress.new(address, port))
      socket.close
      socket = UDPSocket.new(family)
      socket.bind(address, 0)
      socket.local_address.address.should eq address
    end

    it "sends and receives messages" do
      port = unused_local_port

      server = UDPSocket.new(family)
      server.bind(address, port)
      server.local_address.should eq(Socket::IPAddress.new(address, port))

      client = UDPSocket.new(family)
      client.bind(address, 0)

      client.send "message", to: server.local_address
      server.receive.should eq({"message", client.local_address})

      client.connect(address, port)
      client.local_address.family.should eq(family)
      client.local_address.address.should eq(address)
      client.remote_address.should eq(Socket::IPAddress.new(address, port))

      client.send "message"
      server.receive.should eq({"message", client.local_address})

      client.send("laus deo semper")

      buffer = uninitialized UInt8[256]

      bytes_read, client_addr = server.receive(buffer.to_slice)
      message = String.new(buffer.to_slice[0, bytes_read])
      message.should eq("laus deo semper")

      client.send("laus deo semper")

      bytes_read, client_addr = server.receive(buffer.to_slice[0, 4])
      message = String.new(buffer.to_slice[0, bytes_read])
      message.should eq("laus")

      client.close
      server.close
    end
  end

  {% if flag?(:linux) %}
    it "sends broadcast message" do
      port = unused_local_port

      client = UDPSocket.new(Socket::Family::INET)
      client.bind("localhost", 0)
      client.broadcast = true
      client.broadcast?.should be_true
      client.connect("255.255.255.255", port)
      client.send("broadcast").should eq(9)
      client.close
    end
  {% else %}
    pending "sends broadcast message"
  {% end %}
end
