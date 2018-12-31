require "./spec_helper"
require "../../support/errno"

describe TCPSocket do
  describe "#connect" do
    each_ip_family do |family, address|
      it "connects to server" do
        port = unused_local_port

        TCPServer.open(address, port) do |server|
          TCPSocket.open(address, port) do |client|
            client.local_address.address.should eq address

            sock = server.accept

            sock.closed?.should be_false
            client.closed?.should be_false

            sock.local_address.port.should eq(port)
            sock.local_address.address.should eq(address)

            client.remote_address.port.should eq(port)
            sock.remote_address.address.should eq address
          end
        end
      end

      it "raises when connection is refused" do
        port = unused_local_port

        expect_raises_errno(Errno::ECONNREFUSED, "Error connecting to '#{address}:#{port}'") do
          TCPSocket.new(address, port)
        end
      end

      it "raises when port is negative" do
        error = expect_raises(Socket::Addrinfo::Error) do
          TCPSocket.new(address, -12)
        end
        error.error_code.should eq({% if flag?(:linux) %}LibC::EAI_SERVICE{% else %}LibC::EAI_NONAME{% end %})
      end

      it "raises when port is zero" do
        expect_raises_errno({% if flag?(:linux) %}Errno::ECONNREFUSED{% else %}Errno::EADDRNOTAVAIL{% end %}) do
          TCPSocket.new(address, 0)
        end
      end
    end

    describe "address resolution" do
      it "connects to localhost" do
        port = unused_local_port

        TCPServer.open("localhost", port) do |server|
          TCPSocket.open("localhost", port) do |client|
            sock = server.accept
          end
        end
      end

      it "raises when host doesn't exist" do
        expect_raises(Socket::Error, "No address found for doesnotexist.example.org.:12345 over TCP") do
          TCPSocket.new("doesnotexist.example.org.", 12345)
        end
      end

      it "raises (rather than segfault on darwin) when host doesn't exist and port is 0" do
        expect_raises(Socket::Error, /No address found for doesnotexist.example.org.:00? over TCP/) do
          TCPSocket.new("doesnotexist.example.org.", 0)
        end
      end
    end

    it "fails to connect IPv6 to IPv4 server" do
      port = unused_local_port

      TCPServer.open("0.0.0.0", port) do |server|
        expect_raises_errno(Errno::ECONNREFUSED, "Error connecting to '::1:#{port}'") do
          TCPSocket.new("::1", port)
        end
      end
    end
  end

  it "sync from server" do
    port = unused_local_port

    TCPServer.open("::", port) do |server|
      TCPSocket.open("localhost", port) do |client|
        sock = server.accept
        sock.sync?.should eq(server.sync?)
      end

      # test sync flag propagation after accept
      server.sync = !server.sync?

      TCPSocket.open("localhost", port) do |client|
        sock = server.accept
        sock.sync?.should eq(server.sync?)
      end
    end
  end

  it "settings" do
    port = unused_local_port

    TCPServer.open("::", port) do |server|
      TCPSocket.open("localhost", port) do |client|
        # test protocol specific socket options
        (client.tcp_nodelay = true).should be_true
        client.tcp_nodelay?.should be_true
        (client.tcp_nodelay = false).should be_false
        client.tcp_nodelay?.should be_false

        {% unless flag?(:openbsd) %}
        (client.tcp_keepalive_idle = 42).should eq 42
        client.tcp_keepalive_idle.should eq 42
        (client.tcp_keepalive_interval = 42).should eq 42
        client.tcp_keepalive_interval.should eq 42
        (client.tcp_keepalive_count = 42).should eq 42
        client.tcp_keepalive_count.should eq 42
        {% end %}
      end
    end
  end

  it "fails when connection is refused" do
    port = TCPServer.open("localhost", 0) do |server|
      server.local_address.port
    end

    expect_raises_errno(Errno::ECONNREFUSED, "Error connecting to 'localhost:#{port}'") do
      TCPSocket.new("localhost", port)
    end
  end

  it "sends and receives messages" do
    port = unused_local_port

    TCPServer.open("::", port) do |server|
      TCPSocket.open("localhost", port) do |client|
        sock = server.accept

        client << "ping"
        sock.gets(4).should eq("ping")
        sock << "pong"
        client.gets(4).should eq("pong")
      end
    end
  end
end
