require "spec"
require "socket"

describe TCPSocket do
  it "creates a raw socket" do
    sock = TCPSocket.new
    sock.family.should eq(Socket::Family::INET)

    sock = TCPSocket.new(Socket::Family::INET6)
    sock.family.should eq(Socket::Family::INET6)
  end

  it "sends and receives messages" do
    port = TCPServer.open("::", 0) do |server|
      server.local_address.port
    end
    port.should be > 0

    TCPServer.open("::", port) do |server|
      server.local_address.family.should eq(Socket::Family::INET6)
      server.local_address.port.should eq(port)
      server.local_address.address.should eq("::")

      # test protocol specific socket options
      server.reuse_address?.should be_true # defaults to true
      (server.reuse_address = false).should be_false
      server.reuse_address?.should be_false
      (server.reuse_address = true).should be_true
      server.reuse_address?.should be_true

      {% unless flag?(:openbsd) %}
      (server.keepalive = false).should be_false
      server.keepalive?.should be_false
      (server.keepalive = true).should be_true
      server.keepalive?.should be_true
      {% end %}

      (server.linger = nil).should be_nil
      server.linger.should be_nil
      (server.linger = 42).should eq 42
      server.linger.should eq 42

      TCPSocket.open("localhost", server.local_address.port) do |client|
        # The commented lines are actually dependent on the system configuration,
        # so for now we keep it commented. Once we can force the family
        # we can uncomment them.

        # client.local_address.family.should eq(Socket::Family::INET)
        # client.local_address.address.should eq("127.0.0.1")

        sock = server.accept
        sock.sync?.should eq(server.sync?)

        # sock.local_address.family.should eq(Socket::Family::INET6)
        # sock.local_address.port.should eq(12345)
        # sock.local_address.address.should eq("::ffff:127.0.0.1")

        # sock.remote_address.family.should eq(Socket::Family::INET6)
        # sock.remote_address.address.should eq("::ffff:127.0.0.1")

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

        client << "ping"
        sock.gets(4).should eq("ping")
        sock << "pong"
        client.gets(4).should eq("pong")
      end

      # test sync flag propagation after accept
      server.sync = !server.sync?

      TCPSocket.open("localhost", server.local_address.port) do |client|
        sock = server.accept
        sock.sync?.should eq(server.sync?)
      end
    end
  end

  it "fails when connection is refused" do
    port = TCPServer.open("localhost", 0) do |server|
      server.local_address.port
    end

    expect_raises(Errno, "Error connecting to 'localhost:#{port}': Connection refused") do
      TCPSocket.new("localhost", port)
    end
  end

  it "fails when host doesn't exist" do
    expect_raises(Socket::Error, /No address/i) do
      TCPSocket.new("doesnotexist.example.org.", 12345)
    end
  end

  it "fails (rather than segfault on darwin) when host doesn't exist and port is 0" do
    expect_raises(Socket::Error, /No address/i) do
      TCPSocket.new("doesnotexist.example.org.", 0)
    end
  end
end
