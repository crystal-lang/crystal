require "./spec_helper"
require "socket"

describe UDPSocket, tags: "network" do
  # Note: This spec fails with a IPv6 address. See pending below.
  it "#remote_address resets after connect" do
    socket = UDPSocket.new
    socket.connect("127.0.0.1", 1)
    socket.remote_address.port.should eq 1
    socket.connect("127.0.0.1", 2)
    socket.remote_address.port.should eq 2
    socket.close
  end

  pending "#connect with a IPv6 address" do
    socket = UDPSocket.new
    socket.connect("::1", 1)
    socket.close
  end

  each_ip_family do |family, address, unspecified_address|
    it "#bind" do
      port = unused_local_port
      socket = UDPSocket.new(family)
      socket.bind(address, port)
      socket.local_address.should eq(Socket::IPAddress.new(address, port))
      socket.close
      socket = UDPSocket.new(family)
      socket.bind(address, 0)
      socket.local_address.address.should eq address
    ensure
      socket.try &.close
    end

    it "sends and receives messages" do
      port = unused_local_port

      server = UDPSocket.new(family)
      server.bind(address, port)
      server.local_address.should eq(Socket::IPAddress.new(address, port))

      client = UDPSocket.new(family)
      client.bind(address, 0)

      client.send "message", to: server.local_address
      server.receive.should eq({"message", client.local_address})

      client.connect(address, port)
      client.local_address.family.should eq(family)
      client.local_address.address.should eq(address)
      client.remote_address.should eq(Socket::IPAddress.new(address, port))

      client.send "message"
      server.receive.should eq({"message", client.local_address})

      client.send("laus deo semper")

      buffer = uninitialized UInt8[256]

      bytes_read, client_addr = server.receive(buffer.to_slice)
      message = String.new(buffer.to_slice[0, bytes_read])
      message.should eq("laus deo semper")

      client.send("laus deo semper")

      # WSA errors with WSAEMSGSIZE if the buffer is not large enough to receive the message
      {% unless flag?(:win32) %}
        bytes_read, client_addr = server.receive(buffer.to_slice[0, 4])
        message = String.new(buffer.to_slice[0, bytes_read])
        message.should eq("laus")
      {% end %}

      client.close
      server.close
    end

    if {{ flag?(:darwin) }} && family == Socket::Family::INET6
      # Darwin is failing to join IPv6 multicast groups on older versions.
      # However this is known to work on macOS Mojave with Darwin 18.2.0.
      # Darwin also has a bug that prevents selecting the "default" interface.
      # https://lists.apple.com/archives/darwin-kernel/2014/Mar/msg00012.html
      pending "joins and transmits to multicast groups"
    elsif {{ flag?(:dragonfly) }} && family == Socket::Family::INET6
      # TODO: figure out why updating `multicast_loopback` produces a
      # `setsockopt 9: Can't assign requested address
      pending "joins and transmits to multicast groups"
    elsif {{ flag?(:solaris) }} && family == Socket::Family::INET
      # TODO: figure out why updating `multicast_loopback` produces a
      # `setsockopt 18: Invalid argument` error
      pending "joins and transmits to multicast groups"
    elsif {{ flag?(:freebsd) }} && family == Socket::Family::INET6
      # FIXME: fails with "Error sending datagram to [ipv6]:port: Network is unreachable"
      pending "joins and transmits to multicast groups"
    elsif {{ flag?(:netbsd) }} && family == Socket::Family::INET6
      # FIXME: fails with "setsockopt: EADDRNOTAVAIL"
      pending "joins and transmits to multicast groups"
    elsif {{ flag?(:openbsd) }}
      # FIXME: fails with "setsockopt: EINVAL (ipv4) or EADDRNOTAVAIL (ipv6)"
      pending "joins and transmits to multicast groups"
    else
      it "joins and transmits to multicast groups" do
        udp = UDPSocket.new(family)
        port = unused_local_port
        udp.bind(unspecified_address, port)

        udp.multicast_loopback = false
        udp.multicast_loopback?.should eq(false)

        udp.multicast_hops = 4
        udp.multicast_hops.should eq(4)
        udp.multicast_hops = 0
        udp.multicast_hops.should eq(0)

        addr = case family
               when Socket::Family::INET
                 expect_raises(Socket::Error, "Unsupported IP address family: INET. For use with IPv6 only") do
                   udp.multicast_interface 0
                 end

                 begin
                   udp.multicast_interface Socket::IPAddress.new(unspecified_address, 0)
                 rescue e : Socket::Error
                   if e.os_error == Errno::ENOPROTOOPT
                     pending!("Multicast device selection not available on this host")
                   else
                     raise e
                   end
                 end

                 Socket::IPAddress.new("224.0.0.254", port)
               when Socket::Family::INET6
                 expect_raises(Socket::Error, "Unsupported IP address family: INET6. For use with IPv4 only") do
                   udp.multicast_interface(Socket::IPAddress.new(unspecified_address, 0))
                 end

                 begin
                   udp.multicast_interface(0)
                 rescue e : Socket::Error
                   if e.os_error == Errno::ENOPROTOOPT
                     pending!("Multicast device selection not available on this host")
                   else
                     raise e
                   end
                 end

                 Socket::IPAddress.new("ff02::102", port)
               else
                 raise "Unsupported IP address family: #{family}"
               end

        begin
          udp.join_group(addr)
        rescue e : Socket::Error
          if e.os_error == Errno::ENODEV
            pending!("Multicast device selection not available on this host")
          else
            raise e
          end
        end

        udp.multicast_loopback = true
        udp.multicast_loopback?.should eq(true)

        udp.send("testing", addr)
        udp.read_timeout = 1.second
        begin
          udp.receive[0].should eq("testing")
        rescue IO::TimeoutError
          # Since this test doesn't run over the loopback interface, this test
          # fails when there is a firewall in use. Don't fail in that case.
        end

        udp.leave_group(addr)
        udp.send("testing", addr)

        # Test that nothing was received after leaving the multicast group
        spawn do
          sleep 100.milliseconds
          udp.close
        end
        expect_raises(IO::Error) { udp.receive }
        udp.closed?.should be_true
      end
    end
  end

  {% if flag?(:linux) || flag?(:win32) %}
    it "sends broadcast message" do
      port = unused_local_port

      client = UDPSocket.new(Socket::Family::INET)
      client.bind("localhost", 0)
      client.broadcast = true
      client.broadcast?.should be_true
      client.connect("255.255.255.255", port)
      client.send("broadcast").should eq(9)
      client.close
    end
  {% else %}
    pending "sends broadcast message"
  {% end %}
end
