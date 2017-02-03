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
# The `send` methods may sporadically fail with `Errno::ECONNREFUSED` when sending datagrams
# to a non-listening server.
# Wrap with an exception handler to prevent raising. Example:
#
# ```
# begin
#   client.send(message, @destination)
# rescue ex : Errno
#   if ex.errno == Errno::ECONNREFUSED
#     p ex.inspect
#   end
# end
# ```
class UDPSocket < IPSocket
  def initialize(family : Family = Family::INET)
    super(family, Type::DGRAM, Protocol::UDP)
  end

  # Receives a text message from the previously bound address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind("localhost", 1234)
  #
  # message, client_addr = server.receive
  # ```
  def receive(max_message_size = 512) : {String, IPAddress}
    address = nil
    message = String.new(max_message_size) do |buffer|
      bytes_read, sockaddr, addrlen = recvfrom(Slice.new(buffer, max_message_size))
      address = IPAddress.from(sockaddr, addrlen)
      {bytes_read, 0}
    end
    {message, address.not_nil!}
  end

  # Receives a binary message from the previously bound address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind "localhost", 1234
  #
  # message = Bytes.new(32)
  # bytes_read, client_addr = server.receive(message)
  # ```
  def receive(message : Bytes) : {Int32, IPAddress}
    bytes_read, sockaddr, addrlen = recvfrom(message)
    {bytes_read, IPAddress.from(sockaddr, addrlen)}
  end
end
