require "spec"
require "socket"

describe Socket do
  # Tests from libc-test:
  # http://repo.or.cz/libc-test.git/blob/master:/src/functional/inet_pton.c
  it ".ip?" do
    # dotted-decimal notation
    Socket.ip?("0.0.0.0").should be_true
    Socket.ip?("127.0.0.1").should be_true
    Socket.ip?("10.0.128.31").should be_true
    Socket.ip?("255.255.255.255").should be_true

    # numbers-and-dots notation, but not dotted-decimal
    # Socket.ip?("1.2.03.4").should be_false # fails on darwin
    Socket.ip?("1.2.0x33.4").should be_false
    Socket.ip?("1.2.0XAB.4").should be_false
    Socket.ip?("1.2.0xabcd").should be_false
    Socket.ip?("1.0xabcdef").should be_false
    Socket.ip?("00377.0x0ff.65534").should be_false

    # invalid
    Socket.ip?(".1.2.3").should be_false
    Socket.ip?("1..2.3").should be_false
    Socket.ip?("1.2.3.").should be_false
    Socket.ip?("1.2.3.4.5").should be_false
    Socket.ip?("1.2.3.a").should be_false
    Socket.ip?("1.256.2.3").should be_false
    Socket.ip?("1.2.4294967296.3").should be_false
    Socket.ip?("1.2.-4294967295.3").should be_false
    Socket.ip?("1.2. 3.4").should be_false

    # ipv6
    Socket.ip?(":").should be_false
    Socket.ip?("::").should be_true
    Socket.ip?("::1").should be_true
    Socket.ip?(":::").should be_false
    Socket.ip?(":192.168.1.1").should be_false
    Socket.ip?("::192.168.1.1").should be_true
    Socket.ip?("0:0:0:0:0:0:192.168.1.1").should be_true
    Socket.ip?("0:0::0:0:0:192.168.1.1").should be_true
    # Socket.ip?("::012.34.56.78").should be_false # fails on darwin
    Socket.ip?(":ffff:192.168.1.1").should be_false
    Socket.ip?("::ffff:192.168.1.1").should be_true
    Socket.ip?(".192.168.1.1").should be_false
    Socket.ip?(":.192.168.1.1").should be_false
    Socket.ip?("a:0b:00c:000d:E:F::").should be_true
    # Socket.ip?("a:0b:00c:000d:0000e:f::").should be_false # fails on GNU libc
    Socket.ip?("1:2:3:4:5:6::").should be_true
    Socket.ip?("1:2:3:4:5:6:7::").should be_true
    Socket.ip?("1:2:3:4:5:6:7:8::").should be_false
    Socket.ip?("1:2:3:4:5:6:7::9").should be_false
    Socket.ip?("::1:2:3:4:5:6").should be_true
    Socket.ip?("::1:2:3:4:5:6:7").should be_true
    Socket.ip?("::1:2:3:4:5:6:7:8").should be_false
    Socket.ip?("a:b::c:d:e:f").should be_true
    Socket.ip?("ffff:c0a8:5e4").should be_false
    Socket.ip?(":ffff:c0a8:5e4").should be_false
    Socket.ip?("0:0:0:0:0:ffff:c0a8:5e4").should be_true
    Socket.ip?("0:0:0:0:ffff:c0a8:5e4").should be_false
    Socket.ip?("0::ffff:c0a8:5e4").should be_true
    Socket.ip?("::0::ffff:c0a8:5e4").should be_false
    Socket.ip?("c0a8").should be_false
  end

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
end

describe Socket::Addrinfo do
  describe ".resolve" do
    it "returns an array" do
      addrinfos = Socket::Addrinfo.resolve("localhost", 80, type: Socket::Type::STREAM)
      typeof(addrinfos).should eq(Array(Socket::Addrinfo))
      addrinfos.size.should_not eq(0)
    end

    it "yields each result" do
      Socket::Addrinfo.resolve("localhost", 80, type: Socket::Type::DGRAM) do |addrinfo|
        typeof(addrinfo).should eq(Socket::Addrinfo)
      end
    end

    it "eventually raises returned error" do
      expect_raises(Socket::Error) do |addrinfo|
        Socket::Addrinfo.resolve("localhost", 80, type: Socket::Type::DGRAM) do |addrinfo|
          Socket::Error.new("please fail")
        end
      end
    end
  end

  describe ".tcp" do
    it "returns an array" do
      addrinfos = Socket::Addrinfo.tcp("localhost", 80)
      typeof(addrinfos).should eq(Array(Socket::Addrinfo))
      addrinfos.size.should_not eq(0)
    end

    it "yields each result" do
      Socket::Addrinfo.tcp("localhost", 80) do |addrinfo|
        typeof(addrinfo).should eq(Socket::Addrinfo)
      end
    end
  end

  describe ".udp" do
    it "returns an array" do
      addrinfos = Socket::Addrinfo.udp("localhost", 80)
      typeof(addrinfos).should eq(Array(Socket::Addrinfo))
      addrinfos.size.should_not eq(0)
    end

    it "yields each result" do
      Socket::Addrinfo.udp("localhost", 80) do |addrinfo|
        typeof(addrinfo).should eq(Socket::Addrinfo)
      end
    end
  end

  describe "#ip_address" do
    it do
      addrinfos = Socket::Addrinfo.udp("localhost", 80)
      typeof(addrinfos.first.ip_address).should eq(Socket::IPAddress)
    end
  end
end

describe Socket::IPAddress do
  it "transforms an IPv4 address into a C struct and back" do
    addr1 = Socket::IPAddress.new("127.0.0.1", 8080)
    addr2 = Socket::IPAddress.from(addr1.to_unsafe, addr1.size)

    addr2.family.should eq(addr1.family)
    addr2.port.should eq(addr1.port)
    typeof(addr2.address).should eq(String)
    addr2.address.should eq(addr1.address)
  end

  it "transforms an IPv6 address into a C struct and back" do
    addr1 = Socket::IPAddress.new("2001:db8:8714:3a90::12", 8080)
    addr2 = Socket::IPAddress.from(addr1.to_unsafe, addr1.size)

    addr2.family.should eq(addr1.family)
    addr2.port.should eq(addr1.port)
    typeof(addr2.address).should eq(String)
    addr2.address.should eq(addr1.address)
  end

  it "won't resolve domains" do
    expect_raises(Socket::Error, /Invalid IP address/) do
      Socket::IPAddress.new("localhost", 1234)
    end
  end

  it "to_s" do
    Socket::IPAddress.new("127.0.0.1", 80).to_s.should eq("127.0.0.1:80")
    Socket::IPAddress.new("2001:db8:8714:3a90::12", 443).to_s.should eq("[2001:db8:8714:3a90::12]:443")
  end
end

describe Socket::UNIXAddress do
  it "transforms into a C struct and back" do
    addr1 = Socket::UNIXAddress.new("/tmp/service.sock")
    addr2 = Socket::UNIXAddress.from(addr1.to_unsafe, addr1.size)

    addr2.family.should eq(addr1.family)
    addr2.path.should eq(addr1.path)
    addr2.to_s.should eq("/tmp/service.sock")
  end

  it "raises when path is too long" do
    path = "/tmp/crystal-test-too-long-unix-socket-#{("a" * 2048)}.sock"
    expect_raises(ArgumentError, "Path size exceeds the maximum size") { Socket::UNIXAddress.new(path) }
  end

  it "to_s" do
    Socket::UNIXAddress.new("some_path").to_s.should eq("some_path")
  end
end

describe UNIXServer do
  it "raises when path is too long" do
    path = "/tmp/crystal-test-too-long-unix-socket-#{("a" * 2048)}.sock"
    expect_raises(ArgumentError, "Path size exceeds the maximum size") { UNIXServer.new(path) }
    File.exists?(path).should be_false
  end

  it "creates the socket file" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do
      File.exists?(path).should be_true
    end

    File.exists?(path).should be_false
  end

  it "deletes socket file on close" do
    path = "/tmp/crystal-test-unix-sock"

    begin
      server = UNIXServer.new(path)
      server.close
      File.exists?(path).should be_false
    rescue
      File.delete(path) if File.exists?(path)
    end
  end

  it "raises when socket file already exists" do
    path = "/tmp/crystal-test-unix-sock"
    server = UNIXServer.new(path)

    begin
      expect_raises(Errno) { UNIXServer.new(path) }
    ensure
      server.close
    end
  end

  it "won't delete existing file on bind failure" do
    path = "/tmp/crystal-test-unix.sock"

    File.write(path, "")
    File.exists?(path).should be_true

    begin
      expect_raises Errno, /(already|Address) in use/ do
        UNIXServer.new(path)
      end

      File.exists?(path).should be_true
    ensure
      File.delete(path) if File.exists?(path)
    end
  end

  describe "accept" do
    it "returns the client UNIXSocket" do
      UNIXServer.open("/tmp/crystal-test-unix-sock") do |server|
        UNIXSocket.open("/tmp/crystal-test-unix-sock") do |_|
          client = server.accept
          client.should be_a(UNIXSocket)
          client.close
        end
      end
    end

    it "raises when server is closed" do
      server = UNIXServer.new("/tmp/crystal-test-unix-sock")
      exception = nil

      spawn do
        begin
          server.accept
        rescue ex
          exception = ex
        end
      end

      server.close
      until exception
        Fiber.yield
      end

      exception.should be_a(IO::Error)
      exception.try(&.message).should eq("Closed stream")
    end
  end

  describe "accept?" do
    it "returns the client UNIXSocket" do
      UNIXServer.open("/tmp/crystal-test-unix-sock") do |server|
        UNIXSocket.open("/tmp/crystal-test-unix-sock") do |_|
          client = server.accept?.not_nil!
          client.should be_a(UNIXSocket)
          client.close
        end
      end
    end

    it "returns nil when server is closed" do
      server = UNIXServer.new("/tmp/crystal-test-unix-sock")
      ret = :initial

      spawn { ret = server.accept? }
      server.close

      while ret == :initial
        Fiber.yield
      end

      ret.should be_nil
    end
  end
end

describe UNIXSocket do
  it "raises when path is too long" do
    path = "/tmp/crystal-test-too-long-unix-socket-#{("a" * 2048)}.sock"
    expect_raises(ArgumentError, "Path size exceeds the maximum size") { UNIXSocket.new(path) }
    File.exists?(path).should be_false
  end

  it "sends and receives messages" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      server.local_address.family.should eq(Socket::Family::UNIX)
      server.local_address.path.should eq(path)

      UNIXSocket.open(path) do |client|
        client.local_address.family.should eq(Socket::Family::UNIX)
        client.local_address.path.should eq(path)

        server.accept do |sock|
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
    end
  end

  it "sync flag after accept" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      UNIXSocket.open(path) do |client|
        server.accept do |sock|
          sock.sync?.should eq(server.sync?)
        end
      end

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

      expect_raises(IO::Timeout, "Write timed out") do
        loop { left.write buf }
      end

      expect_raises(IO::Timeout, "Read timed out") do
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
end

describe TCPServer do
  it "creates a raw socket" do
    sock = TCPServer.new
    sock.family.should eq(Socket::Family::INET)

    sock = TCPServer.new(Socket::Family::INET6)
    sock.family.should eq(Socket::Family::INET6)
  end

  it "fails when port is in use" do
    port = free_udp_socket_port

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

describe UDPSocket do
  it "creates a raw socket" do
    sock = UDPSocket.new
    sock.family.should eq(Socket::Family::INET)

    sock = UDPSocket.new(Socket::Family::INET6)
    sock.family.should eq(Socket::Family::INET6)
  end

  it "reads and writes data to server" do
    port = free_udp_socket_port

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
