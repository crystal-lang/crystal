# The `Socket` module provides classes for interacting with network sockets.
#
# Protocol implementations:
#
# * `TCPSocket` - TCP/IP network socket
# * `TCPServer` - TCP/IP network socket server
# * `UDPSocket` - UDP network socket
# * `UNIXSocket` - Unix socket
# * `UNIXServer` - Unix socket server
# * `Socket::Raw` - bare OS socket implementation for low level control
module Socket
  # Returns `true` if the string represents a valid IPv4 or IPv6 address.
  def self.ip?(string : String)
    addr = LibC::In6Addr.new
    ptr = pointerof(addr).as(Void*)
    LibC.inet_pton(LibC::AF_INET, string, ptr) > 0 || LibC.inet_pton(LibC::AF_INET6, string, ptr) > 0
  end
end

require "./socket/raw"
require "./socket/server"
require "./socket/tcp_socket"
require "./socket/tcp_server"
require "./socket/unix_socket"
require "./socket/unix_server"
require "./socket/udp_socket"
