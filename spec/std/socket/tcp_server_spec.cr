require "./spec_helper"
require "../../support/errno"

describe TCPServer do
  describe ".new" do
    each_ip_family do |family, address|
      it "listens on local address" do
        port = unused_local_port

        server = TCPServer.new(address, port)

        server.reuse_port?.should be_false
        server.reuse_address?.should be_true

        local_address = Socket::IPAddress.new(address, port)
        server.local_address.should eq local_address

        server.closed?.should be_false

        server.close

        server.closed?.should be_true
        expect_raises_errno(Errno::EBADF, "getsockname: ") do
          server.local_address
        end
      end

      it "binds to port 0" do
        server = TCPServer.new(address, 0)

        server.local_address.address.should eq(address)
        server.local_address.port.should be > 0
      end

      it "raises when port is negative" do
        error = expect_raises(Socket::Addrinfo::Error) do
          TCPServer.new(address, -12)
        end
        error.error_code.should eq({% if flag?(:linux) %}LibC::EAI_SERVICE{% else %}LibC::EAI_NONAME{% end %})
      end

      describe "reuse_port" do
        it "raises when port is in use" do
          TCPServer.open(address, 0) do |server|
            expect_raises_errno(Errno::EADDRINUSE, "bind: ") do
              TCPServer.open(address, server.local_address.port) { }
            end
          end
        end

        it "raises when not binding with reuse_port" do
          TCPServer.open(address, 0, reuse_port: true) do |server|
            expect_raises_errno(Errno::EADDRINUSE, {% if flag?(:linux) %}"listen: "{% else %}"bind: "{% end %}) do
              TCPServer.open(address, server.local_address.port) { }
            end
          end
        end

        it "raises when port is not ready to be reused" do
          TCPServer.open(address, 0) do |server|
            expect_raises_errno(Errno::EADDRINUSE, "bind: ") do
              TCPServer.open(address, server.local_address.port, reuse_port: true) { }
            end
          end
        end

        it "binds to used port with reuse_port = true" do
          TCPServer.open(address, 0, reuse_port: true) do |server|
            TCPServer.open(address, server.local_address.port, reuse_port: true) { }
          end
        end
      end
    end

    describe "address resolution" do
      it "binds to localhost" do
        TCPServer.new("localhost", unused_local_port)
      end

      it "raises when host doesn't exist" do
        expect_raises(Socket::Error, "No address found for doesnotexist.example.org.:12345 over TCP") do
          TCPServer.new("doesnotexist.example.org.", 12345)
        end
      end

      it "raises (rather than segfault on darwin) when host doesn't exist and port is 0" do
        expect_raises(Socket::Error, /No address found for doesnotexist.example.org.:00? over TCP/) do
          TCPServer.new("doesnotexist.example.org.", 0)
        end
      end
    end

    it "binds to all interfaces" do
      port = unused_local_port
      TCPServer.open(port) do |server|
        server.local_address.port.should eq port
      end
    end
  end

  {% if flag?(:linux) %}
    pending "settings"
  {% else %}
    it "settings" do
      TCPServer.open("::", unused_local_port) do |server|
        (server.recv_buffer_size = 42).should eq 42
        server.recv_buffer_size.should eq 42
      end
    end
  {% end %}
end
