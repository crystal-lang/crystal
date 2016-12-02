require "./ip_socket"

# A User Datagram Protocol socket.
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
  def initialize(@family : Family = Family::INET)
    super create_socket(family.value, Type::DGRAM, Protocol::UDP)
  end

  # Binds the UDP socket to a local address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind "localhost", 1234
  # ```
  def bind(host, port, dns_timeout = nil)
    getaddrinfo(host, port, @family, Type::DGRAM, Protocol::UDP, timeout: dns_timeout) do |addrinfo|
      self.reuse_address = true

      ret =
        {% if flag?(:freebsd) || flag?(:openbsd) %}
          LibC.bind(fd, addrinfo.ai_addr.as(LibC::Sockaddr*), addrinfo.ai_addrlen)
        {% else %}
          LibC.bind(fd, addrinfo.ai_addr, addrinfo.ai_addrlen)
        {% end %}
      unless ret == 0
        next false if addrinfo.ai_next
        raise Errno.new("Error binding UDP socket at #{host}:#{port}")
      end

      true
    end
  end

  # Connects the UDP socket to a remote address to send messages to.
  #
  # ```
  # client = UDPSocket.new
  # client.connect("localhost", 1234)
  # client.send("a text message")
  # ```
  def connect(host, port, dns_timeout = nil, connect_timeout = nil)
    getaddrinfo(host, port, @family, Type::DGRAM, Protocol::UDP, timeout: dns_timeout) do |addrinfo|
      if err = nonblocking_connect host, port, addrinfo, timeout: connect_timeout
        next false if addrinfo.ai_next
        raise err
      end

      true
    end
  end

  # Sends a text message to the previously connected remote address. See
  # `#connect`.
  def send(message : String)
    send(message.to_slice)
  end

  # Sends a binary message to the previously connected remote address. See
  # `#connect`.
  def send(message : Slice(UInt8))
    bytes_sent = LibC.send(fd, (message.to_unsafe.as(Void*)), message.size, 0)
    raise Errno.new("Error sending datagram") if bytes_sent == -1
    bytes_sent
  ensure
    if (writers = @writers) && !writers.empty?
      add_write_event
    end
  end

  # Sends a text message to the specified remote address.
  def send(message : String, addr : IPAddress)
    send(message.to_slice, addr)
  end

  # Sends a binary message to the specified remote address.
  def send(message : Slice(UInt8), addr : IPAddress)
    sockaddr = addr.sockaddr
    bytes_sent = LibC.sendto(fd, (message.to_unsafe.as(Void*)), message.size, 0, pointerof(sockaddr).as(LibC::Sockaddr*), addr.addrlen)
    raise Errno.new("Error sending datagram to #{addr}") if bytes_sent == -1
    bytes_sent
  end

  # Receives a binary message on the previously bound address.
  #
  # ```
  # server = UDPSocket.new
  # server.bind "localhost", 1234
  #
  # message = Slice(UInt8).new(32)
  # message_size, client_addr = server.receive(message)
  # ```
  def receive(message : Slice(UInt8)) : {Int32, IPAddress}
    loop do
      sockaddr = uninitialized LibC::SockaddrIn6
      addrlen = LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))
      bytes_read = LibC.recvfrom(fd, (message.to_unsafe.as(Void*)), message.size, 0, pointerof(sockaddr).as(LibC::Sockaddr*), pointerof(addrlen))

      if bytes_read == -1
        if Errno.value == Errno::EAGAIN
          wait_readable
        else
          raise Errno.new("Error receiving datagram")
        end
      else
        return {bytes_read.to_i32, IPAddress.new(sockaddr, addrlen)}
      end
    end
  ensure
    # see IO::FileDescriptor#unbuffered_read
    if (readers = @readers) && !readers.empty?
      add_read_event
    end
  end
end
