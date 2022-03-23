require "spec"
require "socket"

module SocketSpecHelper
  class_getter?(supports_ipv6 : Bool) do
    TCPServer.open("::1", 0) { return true }
    false
  rescue Socket::BindError
    false
  end
end

def pending_ipv6(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
  if SocketSpecHelper.supports_ipv6?
    it(description, file: file, line: line, end_line: end_line, &block)
  else
    pending(description, file: file, line: line, end_line: end_line)
  end
end

def each_ip_family(&block : Socket::Family, String, String ->)
  describe "using IPv4" do
    block.call Socket::Family::INET, "127.0.0.1", "0.0.0.0"
  end

  if SocketSpecHelper.supports_ipv6?
    describe "using IPv6" do
      block.call Socket::Family::INET6, "::1", "::"
    end
  else
    pending "using IPv6"
  end
end

def unused_local_port
  TCPServer.open("::", 0) do |server|
    server.local_address.port
  end
end
