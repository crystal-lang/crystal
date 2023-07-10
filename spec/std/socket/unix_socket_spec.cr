require "spec"
require "socket"
require "../../support/tempfile"

describe UNIXSocket do
  it "raises when path is too long" do
    with_tempfile("unix_socket-too_long-#{("a" * 2048)}.sock") do |path|
      expect_raises(ArgumentError, "Path size exceeds the maximum size") { UNIXSocket.new(path) }
      File.exists?(path).should be_false
    end
  end

  it "sends and receives messages" do
    with_tempfile("unix_socket.sock") do |path|
      UNIXServer.open(path) do |server|
        server.local_address.family.should eq(Socket::Family::UNIX)
        server.local_address.path.should eq(path)

        UNIXSocket.open(path) do |client|
          client.local_address.family.should eq(Socket::Family::UNIX)
          client.local_address.path.should eq(path)

          server.accept do |sock|
            sock.local_address.family.should eq(Socket::Family::UNIX)
            sock.local_address.path.should eq(path)

            sock.remote_address.family.should eq(Socket::Family::UNIX)
            sock.remote_address.path.should eq(path)

            client << "ping"
            sock.gets(4).should eq("ping")
            sock << "pong"
            client.gets(4).should eq("pong")
          end
        end
      end
    end
  end

  it "sync flag after accept" do
    with_tempfile("unix_socket-accept.sock") do |path|
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
  end

  # `LibC.socketpair` is not supported in Winsock 2.0 yet:
  # https://devblogs.microsoft.com/commandline/af_unix-comes-to-windows/#unsupportedunavailable
  {% unless flag?(:win32) %}
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
        buf = ("a" * IO::DEFAULT_BUFFER_SIZE).to_slice

        expect_raises(IO::TimeoutError, "Write timed out") do
          loop { left.write buf }
        end

        expect_raises(IO::TimeoutError, "Read timed out") do
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
  {% end %}
end
