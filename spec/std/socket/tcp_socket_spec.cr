{% skip_file if flag?(:wasm32) %}

require "./spec_helper"
require "../../support/win32"

# TODO: Windows networking in the interpreter requires #12495
{% if flag?(:interpreted) && flag?(:win32) %}
  pending TCPSocket
  {% skip_file %}
{% end %}

describe TCPSocket, tags: "network" do
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

      {% if flag?(:dragonfly) %}
        # FIXME: this spec regularly hangs in a vagrant/libvirt VM
        pending "raises when connection is refused"
      {% else %}
        it "raises when connection is refused" do
          port = unused_local_port

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
        port = unused_local_port

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
        {% else %}
          [Errno.new(LibC::EAI_NONAME), Errno.new(LibC::EAI_AGAIN)].should contain err.os_error
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
        {% else %}
          [Errno.new(LibC::EAI_NONAME), Errno.new(LibC::EAI_AGAIN)].should contain err.os_error
        {% end %}
      end
    end

    it "fails to connect IPv6 to IPv4 server" do
      pending! "IPv6 is unavailable" unless SocketSpecHelper.supports_ipv6?

      port = unused_local_port

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
      port = unused_local_port

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
      port = unused_local_port

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

    it "sends and receives messages (fibers & channels)" do
      port = unused_local_port

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
