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

  it "closes connection to server that doesn't properly terminate SSL session" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair

    client_successfully_closed_socket = Channel(Nil).new
    spawn do
      OpenSSL::SSL::Server.open(tcp_server, server_context, sync_close: true) do |server|
        server_client = server.accept
        # require client to close the socket from its side, without the server closing it, IIS behave this way.
        client_successfully_closed_socket.receive
        server_client.close
      end
    end
    socket = TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port)
    socket = OpenSSL::SSL::Socket::Client.new(socket, client_context, hostname: "example.com", sync_close: true)
    socket.close
    client_successfully_closed_socket.send(nil)
  end
end
