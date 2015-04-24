require "spec"
require "socket"

describe "UNIXSocket" do
  it "sends and receives messages" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      expect(server.addr.family).to eq("AF_UNIX")
      expect(server.addr.path).to eq(path)

      UNIXSocket.open(path) do |client|
        expect(client.addr.family).to eq("AF_UNIX")
        expect(client.addr.path).to eq(path)

        server.accept do |sock|
          expect(sock.addr.family).to eq("AF_UNIX")
          expect(sock.addr.path).to eq("")

          expect(sock.peeraddr.family).to eq("AF_UNIX")
          expect(sock.peeraddr.path).to eq("")

          client << "ping"
          expect(sock.read(4)).to eq("ping")
          sock << "pong"
          expect(client.read(4)).to eq("pong")
        end
      end
    end
  end

  it "creates a pair of sockets" do
    UNIXSocket.pair do |left, right|
      expect(left.addr.family).to eq("AF_UNIX")
      expect(left.addr.path).to eq("")

      left << "ping"
      expect(right.read(4)).to eq("ping")
      right << "pong"
      expect(left.read(4)).to eq("pong")
    end
  end

  it "creates the socket file" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do
      expect(File.exists?(path)).to be_true
    end
  end
end

describe "TCPSocket" do
  it "sends and receives messages" do
    TCPServer.open("::", 12345) do |server|
      expect(server.addr.family).to eq("AF_INET6")
      expect(server.addr.ip_port).to eq(12345)
      expect(server.addr.ip_address).to eq("::")

      TCPSocket.open("localhost", 12345) do |client|
        # The commented lines are actually dependant on the system configuration,
        # so for now we keep it commented. Once we can force the family
        # we can uncomment them.

        # TODO: make pending spec
        #expect(client.addr.family).to eq("AF_INET")
        #expect(client.addr.ip_address).to eq("127.0.0.1")

        sock = server.accept

        #expect(sock.addr.family).to eq("AF_INET6")
        #expect(sock.addr.ip_port).to eq(12345)
        #expect(sock.addr.ip_address).to eq("::ffff:127.0.0.1")

        #expect(sock.peeraddr.family).to eq("AF_INET6")
        #expect(sock.peeraddr.ip_address).to eq("::ffff:127.0.0.1")

        client << "ping"
        expect(sock.read(4)).to eq("ping")
        sock << "pong"
        expect(client.read(4)).to eq("pong")
      end
    end
  end

  it "fails when connection is refused" do
    expect_raises(Errno, "Error connecting to 'localhost:12345': Connection refused") do
      TCPSocket.new("localhost", 12345)
    end
  end

  it "fails when host doesn't exist" do
    expect_raises(SocketError, /^getaddrinfo: .+ not known$/) do
      TCPSocket.new("localhostttttt", 12345)
    end
  end
end

describe "UDPSocket" do
  it "sends and receives messages" do
    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::", 12346)

    expect(server.addr.family).to eq("AF_INET6")
    expect(server.addr.ip_port).to eq(12346)
    expect(server.addr.ip_address).to eq("::")

    client = UDPSocket.new(Socket::Family::INET)
    client.connect("localhost", 12346)

    expect(client.addr.family).to eq("AF_INET")
    expect(client.addr.ip_address).to eq("127.0.0.1")
    expect(client.peeraddr.family).to eq("AF_INET")
    expect(client.peeraddr.ip_port).to eq(12346)
    expect(client.peeraddr.ip_address).to eq("127.0.0.1")

    client << "message"
    expect(server.read(7)).to eq("message")

    client.close
    server.close
  end
end
