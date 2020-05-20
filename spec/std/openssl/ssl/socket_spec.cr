require "spec"
require "socket"
require "../../spec_helper"
require "../../../support/ssl"

describe OpenSSL::SSL::Socket do
  describe OpenSSL::SSL::Socket::Server do
    it "auto accept client by default" do
      TCPServer.open(0) do |tcp_server|
        server_context, client_context = ssl_context_pair

        spawn do
          OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
            socket.print "hello"
          end
        end

        socket = tcp_server.accept
        ssl_server = OpenSSL::SSL::Socket::Server.new(socket, server_context)
        ssl_server.gets.should eq("hello")
        ssl_server.close
      end
    end

    it "doesn't accept client when specified" do
      TCPServer.open(0) do |tcp_server|
        server_context, client_context = ssl_context_pair

        spawn do
          OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
            socket.print "hello"
          end
        end

        socket = tcp_server.accept
        ssl_server = OpenSSL::SSL::Socket::Server.new(socket, server_context, accept: false)
        ssl_server.accept
        ssl_server.gets.should eq("hello")
        ssl_server.close
      end
    end
  end

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

  it "interprets graceful EOF of underlying socket as SSL termination" do
    tcp_server = TCPServer.new(0)
    server_context, client_context = ssl_context_pair
    server_context.disable_session_resume_tickets # avoid Broken pipe

    server_finished_reading = Channel(String).new
    spawn do
      OpenSSL::SSL::Server.open(tcp_server, server_context, sync_close: true) do |server|
        server_socket = server.accept
        received = server_socket.gets_to_end # interprets underlying socket close as a graceful EOF
        server_finished_reading.send(received)
      end
    end
    socket = TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port)
    socket_ssl = OpenSSL::SSL::Socket::Client.new(socket, client_context, hostname: "example.com", sync_close: true)
    socket_ssl.print "hello"
    socket_ssl.flush # needed today see #5375
    socket.close     # close underlying socket without gracefully shutting down SSL at all
    server_received = server_finished_reading.receive
    server_received.should eq("hello")
  end
end
