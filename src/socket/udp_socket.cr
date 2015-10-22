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
  def initialize(family : Socket::Family = Socket::Family::INET)
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

  def sendto(slice : Slice(UInt8), dest_addr : Addr)
    case dest_addr.family
    when "AF_INET"
      d4 = dest_addr.to_sockaddr as LibC::SockAddrIn
      bytes_sent = LibC.sendto(fd, (slice.to_unsafe as Void*), slice.size, 0, pointerof(d4) as LibC::SockAddr*, sizeof(LibC::SockAddrIn))
    when "AF_INET6"
      d6 = dest_addr.to_sockaddr as LibC::SockAddrIn6
      bytes_sent = LibC.sendto(fd, (slice.to_unsafe as Void*), slice.size, 0, pointerof(d6) as LibC::SockAddr*, sizeof(LibC::SockAddrIn6))
    else
      raise "Unsupported family"
    end

    if bytes_sent != -1
      return bytes_sent
    end

    raise Errno.new("Error writing datagram")
  ensure
    add_write_event unless writers.empty?
  end

  def recvfrom(size : Int)
    if size < 0
      raise ArgumentError.new("negative size")
    else
      recvfrom(Slice(UInt8).new(size))
    end
  end

  def recvfrom(slice : Slice(UInt8))
    loop do
      sockaddr :: LibC::SockAddrIn6
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockAddrIn6))

      bytes_read = LibC.recvfrom(fd, (slice.to_unsafe as Void*), slice.size, 0, pointerof(sockaddr) as LibC::SockAddr*, pointerof(addrlen))
      if bytes_read != -1
        return {
          slice[0, bytes_read.to_i32],
          if addrlen == sizeof(LibC::SockAddrIn6)
            Addr.new((pointerof(sockaddr) as LibC::SockAddrIn6*).value)
          else
            Addr.new((pointerof(sockaddr) as LibC::SockAddrIn*).value)
          end
        }
      end

      if LibC.errno == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new("Error receiving datagram")
      end
    end
  ensure
    add_read_event unless readers.empty?
  end
end
