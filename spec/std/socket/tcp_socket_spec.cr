{% skip_file if flag?(:wasm32) %}

require "./spec_helper"
require "../../support/win32"

private class TCPSocketSubclass < TCPSocket
  getter? initialized = false

  def initialize(host : String, port)
    @initialized = true
    super(host, port)
  end

  def initialize(addrinfos : Array, port)
    @initialized = true
    super(addrinfos, "example", port, connection_attempt_delay: 10.milliseconds)
  end
end

# Yields the address of a listening socket whose accept queue is full, so that
# connection attempts to it hang until they time out (the SYN is dropped).
# Marks the spec as pending on platforms that refuse the connection instead.
private def with_stalled_address(&)
  server = TCPServer.new("127.0.0.1", 0, backlog: 1)
  addrinfo = Socket::Addrinfo.tcp("127.0.0.1", server.local_address.port).first
  clients = [] of Socket
  stalled = false

  begin
    # fill the accept queue
    10.times do
      client = Socket.tcp(Socket::Family::INET)
      clients << client
      if error = client.connect(addrinfo, timeout: 50.milliseconds) { |err| err }
        stalled = error.is_a?(IO::TimeoutError)
        break
      end
    end
    pending! "Can't stall connection attempts" unless stalled

    yield addrinfo
  ensure
    clients.each(&.close)
    server.close
  end
end

describe TCPSocket, tags: "network" do
  describe "#connect" do
    each_ip_family do |family, address|
      it "connects to server" do
        port = unused_local_tcp_port

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

      {% if flag?(:dragonfly) %}
        # FIXME: this spec regularly hangs in a vagrant/libvirt VM
        pending "raises when connection is refused"
      {% else %}
        it "raises when connection is refused" do
          port = unused_local_tcp_port

          expect_raises(Socket::ConnectError, "Error connecting to '#{address}:#{port}'") do
            TCPSocket.new(address, port)
          end
        end
      {% end %}

      it "raises when port is negative" do
        error = expect_raises(Socket::Addrinfo::Error) do
          TCPSocket.new(address, -12)
        end
        error.os_error.should eq({% if flag?(:win32) %}
          WinError::WSATYPE_NOT_FOUND
        {% elsif (flag?(:linux) && !flag?(:android)) || flag?(:openbsd) %}
          Errno.new(LibC::EAI_SERVICE)
        {% else %}
          Errno.new(LibC::EAI_NONAME)
        {% end %})
      end

      {% if flag?(:dragonfly) %}
        # FIXME: this spec regularly hangs in a vagrant/libvirt VM
        pending "raises when port is zero"
      {% else %}
        it "raises when port is zero" do
          expect_raises(Socket::ConnectError) do
            TCPSocket.new(address, 0)
          end
        end
      {% end %}
    end

    describe "address resolution" do
      it "connects to localhost" do
        port = unused_local_tcp_port

        TCPServer.open("localhost", port) do |server|
          TCPSocket.open("localhost", port) do |client|
            server.accept
          end
        end
      end

      it "raises when host doesn't exist" do
        err = expect_raises(Socket::Error, "Hostname lookup for doesnotexist.example.org. failed") do
          TCPSocket.new("doesnotexist.example.org.", 12345)
        end
        # FIXME: Resolve special handling for win32. The error code handling should be identical.
        {% if flag?(:win32) %}
          [WinError::WSAHOST_NOT_FOUND, WinError::WSATRY_AGAIN].should contain err.os_error
        {% elsif flag?(:android) || flag?(:netbsd) || flag?(:openbsd) %}
          err.os_error.should eq(Errno.new(LibC::EAI_NODATA))
        {% elsif flag?(:freebsd) %}
          err.os_error.should eq(Errno.new(LibC::EAI_ADDRFAMILY))
        {% else %}
          [Errno.new(LibC::EAI_NONAME), Errno.new(LibC::EAI_NODATA), Errno.new(LibC::EAI_AGAIN)].should contain err.os_error
        {% end %}
      end

      it "raises (rather than segfault on darwin) when host doesn't exist and port is 0" do
        err = expect_raises(Socket::Error, "Hostname lookup for doesnotexist.example.org. failed") do
          TCPSocket.new("doesnotexist.example.org.", 0)
        end
        # FIXME: Resolve special handling for win32. The error code handling should be identical.
        {% if flag?(:win32) %}
          [WinError::WSAHOST_NOT_FOUND, WinError::WSATRY_AGAIN].should contain err.os_error
        {% elsif flag?(:android) || flag?(:netbsd) || flag?(:openbsd) %}
          err.os_error.should eq(Errno.new(LibC::EAI_NODATA))
        {% elsif flag?(:freebsd) %}
          err.os_error.should eq(Errno.new(LibC::EAI_ADDRFAMILY))
        {% else %}
          [Errno.new(LibC::EAI_NONAME), Errno.new(LibC::EAI_NODATA), Errno.new(LibC::EAI_AGAIN)].should contain err.os_error
        {% end %}
      end
    end

    describe "happy eyeballs" do
      it "falls back to the next address immediately when an attempt fails" do
        refused_port = unused_local_tcp_port
        port = unused_local_tcp_port

        TCPServer.open("127.0.0.1", port) do |server|
          addrinfos = [
            Socket::Addrinfo.tcp("127.0.0.1", refused_port).first,
            Socket::Addrinfo.tcp("127.0.0.1", port).first,
          ]

          elapsed = Time.measure do
            # the attempt delay is long: we must not wait for it
            TCPSocket.new(addrinfos, "127.0.0.1", port, connection_attempt_delay: 10.seconds).close
          end
          elapsed.should be < 5.seconds

          server.accept.close
        end
      end

      it "starts the next attempt in parallel after the attempt delay" do
        port = unused_local_tcp_port

        TCPServer.open("127.0.0.1", port) do |server|
          addrinfos = [
            # TEST-NET-1 (RFC 5737): never answers (or is unreachable)
            Socket::Addrinfo.tcp("192.0.2.1", port).first,
            Socket::Addrinfo.tcp("127.0.0.1", port).first,
          ]

          client = nil
          elapsed = Time.measure do
            client = TCPSocket.new(addrinfos, "example", port, connect_timeout: 30.seconds, connection_attempt_delay: 10.milliseconds)
          end
          elapsed.should be < 10.seconds

          client = client.should_not be_nil
          client.remote_address.address.should eq("127.0.0.1")
          client << "ping"
          sock = server.accept
          sock.gets(4).should eq("ping")
          sock.close
          client.close
        end
      end

      it "raises the last error when all attempts fail" do
        port1 = unused_local_tcp_port
        port2 = unused_local_tcp_port

        addrinfos = [
          Socket::Addrinfo.tcp("127.0.0.1", port1).first,
          Socket::Addrinfo.tcp("127.0.0.1", port2).first,
        ]

        expect_raises(Socket::ConnectError, "Error connecting to 'example:1234'") do
          TCPSocket.new(addrinfos, "example", 1234, connection_attempt_delay: 10.milliseconds)
        end
      end

      it "tries addresses sequentially with fast_fallback: false" do
        with_stalled_address do |stalled|
          TCPServer.open("127.0.0.1", 0) do |server|
            addrinfos = [stalled, Socket::Addrinfo.tcp("127.0.0.1", server.local_address.port).first]

            client = nil
            elapsed = Time.measure do
              client = TCPSocket.new(addrinfos, "example", 1234, connect_timeout: 200.milliseconds,
                fast_fallback: false, connection_attempt_delay: 1.millisecond)
            end
            # waited for the first attempt to time out
            elapsed.should be >= 200.milliseconds

            client = client.should_not be_nil
            client.remote_address.should eq(server.local_address)
            client.close
            server.accept.close
          end
        end
      end

      it ".fast_fallback=" do
        TCPSocket.fast_fallback?.should be_true

        TCPSocket.fast_fallback = false
        TCPSocket.fast_fallback?.should be_false

        # shared with subclasses
        TCPSocketSubclass.fast_fallback?.should be_false
        TCPSocketSubclass.fast_fallback = true
        TCPSocket.fast_fallback?.should be_true

        TCPSocket.fast_fallback = false
        TCPServer.open("localhost", 0) do |server|
          TCPSocket.open("localhost", server.local_address.port) do
            server.accept.close
          end
        end
      ensure
        TCPSocket.fast_fallback = true
      end

      it "connects with a subclass" do
        TCPServer.open("127.0.0.1", 0) do |server|
          port = server.local_address.port
          addrinfos = [
            Socket::Addrinfo.tcp("192.0.2.1", port).first,
            Socket::Addrinfo.tcp("127.0.0.1", port).first,
          ]

          socket = TCPSocketSubclass.new(addrinfos, port)
          begin
            socket.initialized?.should be_true
            socket.remote_address.should eq(server.local_address)
            server.accept.close
          ensure
            socket.close
          end

          socket = TCPSocketSubclass.new("localhost", port)
          begin
            socket.initialized?.should be_true
            server.accept.close
          ensure
            socket.close
          end
        end
      end
    end

    it "fails to connect IPv6 to IPv4 server" do
      pending! "IPv6 is unavailable" unless SocketSpecHelper.supports_ipv6?

      port = unused_local_tcp_port

      TCPServer.open("0.0.0.0", port) do |server|
        expect_raises(Socket::ConnectError, "Error connecting to '::1:#{port}'") do
          TCPSocket.new("::1", port)
        end
      end
    end
  end

  {% if flag?(:dragonfly) %}
    # FIXME: these specs regularly hang in a vagrant/libvirt VM
    pending "sync from server"
    pending "settings"
    pending "fails when connection is refused"
    pending "sends and receives messages"
    pending "sends and receives messages (fibers & channels)"
  {% else %}
    it "sync from server" do
      port = unused_local_tcp_port

      TCPServer.open(Socket::IPAddress::UNSPECIFIED, port) do |server|
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
      port = unused_local_tcp_port

      TCPServer.open(Socket::IPAddress::UNSPECIFIED, port) do |server|
        TCPSocket.open("localhost", port) do |client|
          # test protocol specific socket options
          (client.tcp_nodelay = true).should be_true
          client.tcp_nodelay?.should be_true
          (client.tcp_nodelay = false).should be_false
          client.tcp_nodelay?.should be_false

          {% unless flag?(:openbsd) || flag?(:netbsd) %}
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

      expect_raises(Socket::ConnectError, "Error connecting to 'localhost:#{port}'") do
        TCPSocket.new("localhost", port)
      end
    end

    it "sends and receives messages" do
      port = unused_local_tcp_port

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

    it "sends and receives messages (fibers & channels)" do
      port = unused_local_tcp_port

      channel = Channel(Exception?).new
      spawn do
        TCPServer.open(Socket::IPAddress::UNSPECIFIED, port) do |server|
          channel.send nil
          sock = server.accept
          sock.read_timeout = 3.second
          sock.write_timeout = 3.second

          sock.gets(4).should eq("ping")
          sock << "pong"
          channel.send nil
        end
      rescue exc
        channel.send exc
      end

      if exc = channel.receive
        raise exc
      end

      TCPSocket.open("localhost", port) do |client|
        client.read_timeout = 3.second
        client.write_timeout = 3.second
        client << "ping"
        client.gets(4).should eq("pong")
      end

      if exc = channel.receive
        raise exc
      end
    end
  {% end %}
end
