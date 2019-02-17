require "spec"
require "socket"
require "../../spec_helper"
require "../../../support/ssl"

describe OpenSSL::SSL::Socket do
  it "knows which cipher that is in use" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair

    OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
      spawn do
        OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
        end
      end

      client = server.accept
      client.cipher.should contain "RSA"
      client.close
    end
  end

  it "knows which TLS version that is in use" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair

    OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
      spawn do
        OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
        end
      end

      client = server.accept
      client.tls_version.should_not be_nil
      client.tls_version.not_nil!.should contain "TLS"
      client.close
    end
  end
end
