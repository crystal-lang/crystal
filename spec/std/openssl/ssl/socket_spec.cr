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

  it "accepts clients that only write then close the connection" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair
    # in tls 1.3, if clients don't read anything and close the connection
    # the server still try and write to it a ticket, resulting in a "pipe failure"
    # this context method disables the tickets which allows the behavior:
    server_context.disable_session_resume_tickets

    OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
      spawn do
        # the :sync_close aspect, as implemented in crystal, effects a unidirectional socket close from the client
        OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com", sync_close: true) do |socket|
          # doesn't read anything, just write and close connection immediately
          socket.puts "hello"
        end
      end

      client = server.accept # shouldn't raise "Broken pipe (Errno)"
      client.close
    end
  end

  it "closes connection to server that doesn't properly terminate SSL session" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair
    server_context.disable_session_resume_tickets # avoid Broken pipe

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
