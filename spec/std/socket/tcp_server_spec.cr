require "./spec_helper"
require "socket"

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
        expect_raises(Errno, "getsockname: Bad file descriptor") do
          server.local_address
        end
      end

      it "binds to port 0" do
        server = TCPServer.new(address, 0)

        server.local_address.address.should eq(address)
        server.local_address.port.should be > 0
      end

      it "raises when port is negative" do
        expect_raises(Socket::Error, linux? ? "getaddrinfo: Servname not supported for ai_socktype" : "No address found for #{address}:-12 over TCP") do
          TCPServer.new(address, -12)
        end
      end

      describe "reuse_port" do
        it "raises when port is in use" do
          TCPServer.open(address, 0) do |server|
            expect_raises Errno, /(already|Address) in use/ do
              TCPServer.open(address, server.local_address.port) { }
            end
          end
        end

        it "raises when not binding with reuse_port" do
          TCPServer.open(address, 0, reuse_port: true) do |server|
            expect_raises Errno, /(already|Address) in use/ do
              TCPServer.open(address, server.local_address.port) { }
            end
          end
        end

        it "raises when port is not ready to be reused" do
          TCPServer.open(address, 0) do |server|
            expect_raises Errno, /(already|Address) in use/ do
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
        expect_raises(Socket::Error, "No address") do
          TCPServer.new("doesnotexist.example.org.", 12345)
        end
      end

      it "raises (rather than segfault on darwin) when host doesn't exist and port is 0" do
        expect_raises(Socket::Error, "No address") do
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
