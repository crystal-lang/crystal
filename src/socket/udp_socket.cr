require "./ip_socket"

# A User Datagram Protocol socket.
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
# This implementation supports both IPv4 and IPv6 addresses. For IPv4 addresses you need use
# `Socket::Family::INET` family (used by default). And `Socket::Family::INET6` for IPv6
# addresses accordingly.
#
# Usage example:
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
# client.puts "message" # send message to server
# server.gets           # => "message\n"
#
# # Close client and server
# client.close
# server.close
# ```
class UDPSocket < IPSocket
  def initialize(family = Socket::Family::INET : Socket::Family)
    super create_socket(family.value, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP)
  end

  # Creates a UDP socket from the given address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind "localhost", 1234
  # ```
  def bind(host, port, dns_timeout = nil)
    getaddrinfo(host, port, nil, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP, timeout: dns_timeout) do |ai|
      self.reuse_address = true

      if LibC.bind(fd, ai.addr, ai.addrlen) != 0
        next false if ai.next
        raise Errno.new("Error binding UDP socket at #{host}:#{port}")
      end

      true
    end
  end

  # Attempts to connect the socket to a remote address and port for this socket.
  #
  # ```
  # client = UDPSocket.new
  # client.connect "localhost", 1234
  # ```
  def connect(host, port, dns_timeout = nil, connect_timeout = nil)
    getaddrinfo(host, port, nil, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP, timeout: dns_timeout) do |ai|
      if err = nonblocking_connect host, port, ai, timeout: connect_timeout
        next false if ai.next
        raise err
      end

      true
    end
  end
end
