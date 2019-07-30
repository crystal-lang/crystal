require "spec"
require "socket"
require "../../spec_helper"
require "../../../support/ssl"

describe OpenSSL::SSL::Socket do
  it "returns the cipher that is currently in use" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair

    OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
      spawn do
        OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
        end
      end

      client = server.accept
      client.cipher.should_not be_empty
      client.close
    end
  end

  it "returns the TLS version" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair

    OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
      spawn do
        OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
        end
      end

      client = server.accept
      client.tls_version.should contain "TLS"
      client.close
    end
  end
end
