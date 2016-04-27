require "spec"
require "socket"

describe Socket::IPAddress do
  it "transforms an IPv4 address into a C struct and back again" do
    addr1 = Socket::IPAddress.new(Socket::Family::INET, "127.0.0.1", 8080.to_i16)
    addr2 = Socket::IPAddress.new(addr1.sockaddr, addr1.addrlen)

    addr1.family.should eq(addr2.family)
    addr1.port.should eq(addr2.port)
    addr1.address.should eq(addr2.address)
    addr1.to_s.should eq("127.0.0.1:8080")
  end

  it "transforms an IPv6 address into a C struct and back again" do
    addr1 = Socket::IPAddress.new(Socket::Family::INET6, "2001:db8:8714:3a90::12", 8080.to_i16)
    addr2 = Socket::IPAddress.new(addr1.sockaddr, addr1.addrlen)

    addr1.family.should eq(addr2.family)
    addr1.port.should eq(addr2.port)
    addr1.address.should eq(addr2.address)
    addr1.to_s.should eq("2001:db8:8714:3a90::12:8080")
  end
end

describe Socket::UNIXAddress do
  it "does to_s" do
    Socket::UNIXAddress.new("some_path").to_s.should eq("some_path")
  end
end

describe UNIXSocket do
  it "sends and receives messages" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      server.local_address.family.should eq(Socket::Family::UNIX)
      server.local_address.path.should eq(path)

      UNIXSocket.open(path) do |client|
        client.local_address.family.should eq(Socket::Family::UNIX)
        client.local_address.path.should eq(path)

        server.accept do |sock|
          sock.sync?.should eq(server.sync?)

          sock.local_address.family.should eq(Socket::Family::UNIX)
          sock.local_address.path.should eq("")

          sock.remote_address.family.should eq(Socket::Family::UNIX)
          sock.remote_address.path.should eq("")

          client << "ping"
          sock.gets(4).should eq("ping")
          sock << "pong"
          client.gets(4).should eq("pong")
        end
      end

      # test sync flag propagation after accept
      server.sync = !server.sync?

      UNIXSocket.open(path) do |client|
        server.accept do |sock|
          sock.sync?.should eq(server.sync?)
        end
      end
    end
  end

  it "creates a pair of sockets" do
    UNIXSocket.pair do |left, right|
      left.local_address.family.should eq(Socket::Family::UNIX)
      left.local_address.path.should eq("")

      left << "ping"
      right.gets(4).should eq("ping")
      right << "pong"
      left.gets(4).should eq("pong")
    end
  end

  it "tests read and write timeouts" do
    UNIXSocket.pair do |left, right|
      # BUG: shrink the socket buffers first
      left.write_timeout = 0.0001
      right.read_timeout = 0.0001
      buf = ("a" * 4096).to_slice

      expect_raises(IO::Timeout, "write timed out") do
        loop { left.write buf }
      end

      expect_raises(IO::Timeout, "read timed out") do
        loop { right.read buf }
      end
    end
  end

  it "tests socket options" do
    UNIXSocket.pair do |left, right|
      size = 12000
      # linux returns size * 2
      sizes = [size, size * 2]

      (left.send_buffer_size = size).should eq(size)
      sizes.should contain(left.send_buffer_size)

      (left.recv_buffer_size = size).should eq(size)
      sizes.should contain(left.recv_buffer_size)
    end
  end

  it "creates the socket file" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do
      File.exists?(path).should be_true
    end
  end
end

describe TCPServer do
  it "fails when port is in use" do
    expect_raises Errno, /(already|Address) in use/ do
      TCPServer.open("::", 0) do |server|
        TCPServer.open("::", server.local_address.port) { }
      end
    end
  end
end

describe TCPSocket do
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

      (server.keepalive = false).should be_false
      server.keepalive?.should be_false
      (server.keepalive = true).should be_true
      server.keepalive?.should be_true

      (server.linger = nil).should be_nil
      server.linger.should be_nil
      (server.linger = 42).should eq 42
      server.linger.should eq 42

      TCPSocket.open("::", server.local_address.port) do |client|
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

        (client.tcp_keepalive_idle = 42).should eq 42
        client.tcp_keepalive_idle.should eq 42
        (client.tcp_keepalive_interval = 42).should eq 42
        client.tcp_keepalive_interval.should eq 42
        (client.tcp_keepalive_count = 42).should eq 42
        client.tcp_keepalive_count.should eq 42

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
    port = 0
    TCPServer.open("localhost", port) do |server|
      port = server.local_address.port
    end

    expect_raises(Errno, "Error connecting to 'localhost:#{port}': Connection refused") do
      TCPSocket.new("localhost", port)
    end
  end

  it "fails when host doesn't exist" do
    expect_raises(Socket::Error, /^getaddrinfo: (.+ not known|no address .+|Non-recoverable failure in name resolution|Name does not resolve)$/i) do
      TCPSocket.new("localhostttttt", 12345)
    end
  end
end

describe UDPSocket do
  it "sends and receives messages by reading and writing" do
    port = free_udp_socket_port

    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::", port)

    server.local_address.family.should eq(Socket::Family::INET6)
    server.local_address.port.should eq(port)
    server.local_address.address.should eq("::")

    client = UDPSocket.new(Socket::Family::INET6)
    client.connect("::1", port)

    client.local_address.family.should eq(Socket::Family::INET6)
    client.local_address.address.should eq("::1")
    client.remote_address.family.should eq(Socket::Family::INET6)
    client.remote_address.port.should eq(port)
    client.remote_address.address.should eq("::1")

    client << "message"
    server.gets(7).should eq("message")

    client.close
    server.close
  end

  it "sends and receives messages by send and receive over IPv4" do
    port = free_udp_socket_port

    server = UDPSocket.new(Socket::Family::INET)
    server.bind("127.0.0.1", port)

    client = UDPSocket.new(Socket::Family::INET)

    buffer = uninitialized UInt8[256]

    client.send("message equal to buffer", server.local_address)
    bytes_read, addr1 = server.receive(buffer.to_slice[0, 23])
    message1 = String.new(buffer.to_slice[0, bytes_read])
    message1.should eq("message equal to buffer")
    addr1.family.should eq(server.local_address.family)
    addr1.address.should eq(server.local_address.address)

    client.send("message less than buffer", server.local_address)
    bytes_read, addr2 = server.receive(buffer.to_slice)
    message2 = String.new(buffer.to_slice[0, bytes_read])
    message2.should eq("message less than buffer")
    addr2.family.should eq(server.local_address.family)
    addr2.address.should eq(server.local_address.address)

    server.close
    client.close
  end

  it "sends and receives messages by send and receive over IPv6" do
    port = free_udp_socket_port

    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::1", port)

    client = UDPSocket.new(Socket::Family::INET6)

    buffer = uninitialized UInt8[1500]

    client.send("message", server.local_address)
    bytes_read, addr = server.receive(buffer.to_slice)
    String.new(buffer.to_slice[0, bytes_read]).should eq("message")
    addr.family.should eq(server.local_address.family)
    addr.address.should eq(server.local_address.address)

    server.close
    client.close
  end

  it "broadcast messages" do
    port = free_udp_socket_port

    client = UDPSocket.new(Socket::Family::INET)
    client.broadcast = true
    client.broadcast?.should be_true
    client.connect("255.255.255.255", port)
    client.send("broadcast").should eq(9)
    client.close
  end
end

private def free_udp_socket_port
  server = UDPSocket.new(Socket::Family::INET6)
  server.bind("::", 0)
  port = server.local_address.port
  server.close
  port.should be > 0
  port
end
