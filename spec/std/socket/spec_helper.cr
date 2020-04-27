require "spec"
require "socket"

def unused_local_port
  TCPServer.open("::", 0) do |server|
    server.local_address.port
  end
end

def each_ip_family(&block : Socket::Family, String, String ->)
  describe "using IPv4" do
    block.call Socket::Family::INET, "127.0.0.1", "0.0.0.0"
  end

  describe "using IPv6" do
    block.call Socket::Family::INET6, "::1", "::"
  end
end
