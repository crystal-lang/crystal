require "./ip_socket"

# A User Datagram Protocol (UDP) socket.
#
# UDP runs on top of the Internet Protocol (IP) and was developed for applications that do
# not require reliability, acknowledgement, or flow control features at the transport layer.
# This simple protocol provides transport layer addressing in the form of UDP ports and an
# optional checksum capability.
#
# UDP is a very simple protocol. Messages, so called datagrams, are sent to other hosts on
# an IP network without the need to set up special transmission channels or data paths
# beforehand. The UDP socket only needs to be opened for communication. It listens for
# incoming messages and sends outgoing messages on request.
#
# This implementation supports both IPv4 and IPv6 addresses. For IPv4 addresses you must use
# `Socket::Family::INET` family (default) or `Socket::Family::INET6` for IPv6 # addresses.
#
# NOTE: To use `UDPSocket`, you must explicitly import it with `require "socket"`
#
# Usage example:
#
# ```
# require "socket"
#
# # Create server
# server = UDPSocket.new
# server.bind "localhost", 1234
#
# # Create client and connect to server
# client = UDPSocket.new
# client.connect "localhost", 1234
#
# # Send a text message to server
# client.send "message"
#
# # Receive text message from client
# message, client_addr = server.receive
#
# # Close client and server
# client.close
# server.close
# ```
#
# The `send` methods may sporadically fail with `Socket::ConnectError` when sending datagrams
# to a non-listening server.
# Wrap with an exception handler to prevent raising. Example:
#
# ```
# begin
#   client.send(message, @destination)
# rescue ex : Socket::ConnectError
#   p ex.inspect
# end
# ```
class UDPSocket < IPSocket
  def initialize(family : Family = Family::INET)
    super(family, Type::DGRAM, Protocol::UDP)
  end

  # Receives a text message from the previously bound address.
  #
  # ```
  # require "socket"
  #
  # server = UDPSocket.new
  # server.bind("localhost", 1234)
  #
  # message, client_addr = server.receive
  # ```
  def receive(max_message_size = 512) : {String, IPAddress}
    address = nil
    message = String.new(max_message_size) do |buffer|
      bytes_read, sockaddr, addrlen = system_receive(Slice.new(buffer, max_message_size))
      address = IPAddress.from(sockaddr, addrlen)
      {bytes_read, 0}
    end
    {message, address.not_nil!}
  end

  # Receives a binary message from the previously bound address.
  #
  # ```
  # require "socket"
  #
  # server = UDPSocket.new
  # server.bind "localhost", 1234
  #
  # message = Bytes.new(32)
  # bytes_read, client_addr = server.receive(message)
  # ```
  def receive(message : Bytes) : {Int32, IPAddress}
    bytes_read, sockaddr, addrlen = system_receive(message)
    {bytes_read, IPAddress.from(sockaddr, addrlen)}
  end

  # Reports whether transmitted multicast packets should be copied and sent
  # back to the originator.
  def multicast_loopback? : Bool
    case @family
    when Family::INET
      getsockopt_bool LibC::IP_MULTICAST_LOOP, LibC::IPPROTO_IP
    when Family::INET6
      getsockopt_bool LibC::IPV6_MULTICAST_LOOP, LibC::IPPROTO_IPV6
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
  end

  # Sets whether transmitted multicast packets should be copied and sent back
  # to the originator, if the host has joined the multicast group.
  def multicast_loopback=(val : Bool)
    case @family
    when Family::INET
      setsockopt_bool LibC::IP_MULTICAST_LOOP, val, LibC::IPPROTO_IP
    when Family::INET6
      setsockopt_bool LibC::IPV6_MULTICAST_LOOP, val, LibC::IPPROTO_IPV6
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
  end

  # Returns the current value of the `hoplimit` field on uni-cast packets.
  # Datagrams with a `hoplimit` of `1` are not forwarded beyond the local network.
  # Multicast datagrams with a `hoplimit` of `0` will not be transmitted on any
  # network, but may be delivered locally if the sending host belongs to the
  # destination group and multicast loopback is enabled.
  def multicast_hops : Int32
    case @family
    when Family::INET
      getsockopt LibC::IP_MULTICAST_TTL, 0, LibC::IPPROTO_IP
    when Family::INET6
      getsockopt LibC::IPV6_MULTICAST_HOPS, 0, LibC::IPPROTO_IPV6
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
  end

  # The multicast hops option controls the `hoplimit` field on uni-cast packets.
  # If `-1` is specified, the kernel will use a default value.
  # If a value of `0` to `255` is specified, the packet will have the specified
  # value as `hoplimit`. Other values are considered invalid and `Socket::Error` will be raised.
  # Datagrams with a `hoplimit` of `1` are not forwarded beyond the local network.
  # Multicast datagrams with a `hoplimit` of `0` will not be transmitted on any
  # network, but may be delivered locally if the sending host belongs to the
  # destination group and multicast loopback is enabled.
  def multicast_hops=(val : Int)
    case @family
    when Family::INET
      setsockopt LibC::IP_MULTICAST_TTL, val, LibC::IPPROTO_IP
    when Family::INET6
      setsockopt LibC::IPV6_MULTICAST_HOPS, val, LibC::IPPROTO_IPV6
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
    val
  end

  # For hosts with multiple interfaces, each multicast transmission is sent
  # from the primary network interface. This function overrides the default
  # IPv4 interface address for subsequent transmissions. Setting the interface
  # to `0.0.0.0` will select the default interface.
  # Raises `Socket::Error` unless the socket is IPv4 and an IPv4 address is provided.
  def multicast_interface(address : IPAddress)
    if @family == Family::INET
      addr = address.@addr
      if addr.is_a?(LibC::InAddr)
        setsockopt LibC::IP_MULTICAST_IF, addr, LibC::IPPROTO_IP
      else
        raise Socket::Error.new "Expecting an IPv4 interface address. Address provided: #{address.address}"
      end
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}. For use with IPv4 only"
    end
  end

  # For hosts with multiple interfaces, each multicast transmission is sent
  # from the primary network interface. This function overrides the default
  # IPv6 interface for subsequent transmissions. Setting the interface to
  # index `0` will select the default interface.
  def multicast_interface(index : UInt32)
    if @family == Family::INET6
      setsockopt LibC::IPV6_MULTICAST_IF, index, LibC::IPPROTO_IPV6
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}. For use with IPv6 only"
    end
  end

  # A host must become a member of a multicast group before it can receive
  # datagrams sent to the group.
  # Raises `Socket::Error` if an incompatible address is provided.
  def join_group(address : IPAddress)
    case @family
    when Family::INET
      group_modify(address, LibC::IP_ADD_MEMBERSHIP)
    when Family::INET6
      group_modify(address, LibC::IPV6_JOIN_GROUP)
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
  end

  # Drops membership to the specified group. Memberships are automatically
  # dropped when the socket is closed or the process exits.
  # Raises `Socket::Error` if an incompatible address is provided.
  def leave_group(address : IPAddress)
    case @family
    when Family::INET
      group_modify(address, LibC::IP_DROP_MEMBERSHIP)
    when Family::INET6
      group_modify(address, LibC::IPV6_LEAVE_GROUP)
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
  end

  private def group_modify(ip, operation)
    ip_addr = ip.@addr

    case @family
    when Family::INET
      if ip_addr.is_a?(LibC::InAddr)
        req = LibC::IpMreq.new
        req.imr_multiaddr = ip_addr

        setsockopt operation, req, LibC::IPPROTO_IP
      else
        raise Socket::Error.new "Expecting an IPv4 multicast address. Address provided: #{ip.address}"
      end
    when Family::INET6
      if ip_addr.is_a?(LibC::In6Addr)
        req = LibC::Ipv6Mreq.new
        req.ipv6mr_multiaddr = ip_addr

        setsockopt operation, req, LibC::IPPROTO_IPV6
      else
        raise Socket::Error.new "Expecting an IPv6 multicast address. Address provided: #{ip.address}"
      end
    else
      raise Socket::Error.new "Unsupported IP address family: #{@family}"
    end
  end
end
