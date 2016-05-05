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
#
# The `send` methods may sporadically fail with `Errno::ECONNREFUSED` when sending datagrams
# to a non-listening server.
# Wrap with an exception handler to prevent raising. Example:
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
    getaddrinfo(host, port, nil, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP, timeout: dns_timeout) do |addrinfo|
      self.reuse_address = true

      ifdef freebsd
        ret = LibC.bind(fd, addrinfo.ai_addr as LibC::Sockaddr*, addrinfo.ai_addrlen)
      else
        ret = LibC.bind(fd, addrinfo.ai_addr, addrinfo.ai_addrlen)
      end
      unless ret == 0
        next false if addrinfo.ai_next
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
    getaddrinfo(host, port, nil, LibC::SOCK_DGRAM, LibC::IPPROTO_UDP, timeout: dns_timeout) do |addrinfo|
      if err = nonblocking_connect host, port, addrinfo, timeout: connect_timeout
        next false if addrinfo.ai_next
        raise err
      end

      true
    end
  end

  def send(string : String)
    send(string.to_slice)
  end

  def send(slice : Slice(UInt8))
    bytes_sent = LibC.send(fd, (slice.to_unsafe as Void*), slice.size, 0)
    if bytes_sent != -1
      return bytes_sent
    end

    raise Errno.new("Error writing datagram")
  ensure
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  def send(string : String, addr : IPAddress)
    send(string.to_slice, addr)
  end

  def send(slice : Slice(UInt8), addr : IPAddress)
    sockaddr = addr.sockaddr
    bytes_sent = LibC.sendto(fd, (slice.to_unsafe as Void*), slice.size, 0, pointerof(sockaddr) as LibC::Sockaddr*, addr.addrlen)
    if bytes_sent != -1
      return bytes_sent
    end

    raise Errno.new("Error writing datagram")
  end

  def receive(slice : Slice(UInt8)) : {Int32, IPAddress}
    loop do
      sockaddr = uninitialized LibC::SockaddrIn6
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))

      bytes_read = LibC.recvfrom(fd, (slice.to_unsafe as Void*), slice.size, 0, pointerof(sockaddr) as LibC::Sockaddr*, pointerof(addrlen))
      if bytes_read != -1
        return {
          bytes_read.to_i32,
          IPAddress.new(sockaddr, addrlen),
        }
      end

      if Errno.value == Errno::EAGAIN
        wait_readable
      else
        raise Errno.new("Error receiving datagram")
      end
    end
  ensure
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end
end
