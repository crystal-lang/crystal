require "spec"
require "socket"
require "../../spec_helper"
require "../../socket/spec_helper"
require "../../../support/ssl"

describe OpenSSL::SSL::Socket do
  describe OpenSSL::SSL::Socket::Server do
    it "auto accept client by default" do
      TCPServer.open("127.0.0.1", 0) do |tcp_server|
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
      TCPServer.open("127.0.0.1", 0) do |tcp_server|
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
end

private alias Server = OpenSSL::SSL::Socket::Server
private alias Client = OpenSSL::SSL::Socket::Client

private def socket_test(server_tests, client_tests)
  tcp_server = TCPServer.new("127.0.0.1", 0)
  server_context, client_context = ssl_context_pair

  OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
    spawn do
      Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
        client_tests.call(socket)
      end
    end

    client = server.accept
    server_tests.call(client)
    client.close
  end
end

describe OpenSSL::SSL::Socket do
  it "returns the cipher that is currently in use" do
    socket_test(
      server_tests: ->(client : Server) {
        client.cipher.should_not be_empty
      },
      client_tests: ->(client : Client) {}
    )
  end

  it "returns the TLS version" do
    socket_test(
      server_tests: ->(client : Server) {
        client.tls_version.should contain "TLS"
      },
      client_tests: ->(client : Client) {}
    )
  end

  it "returns the peer certificate" do
    socket_test(
      server_tests: ->(client : Server) {
        client.peer_certificate.should be_nil
      },
      client_tests: ->(client : Client) {
        client.peer_certificate.should_not be_nil
      }
    )
  end

  it "returns selected alpn protocol" do
    tcp_server = TCPServer.new("127.0.0.1", 0)
    server_context, client_context = ssl_context_pair

    server_context.alpn_protocol = "h2"
    client_context.alpn_protocol = "h2"

    OpenSSL::SSL::Server.open(tcp_server, server_context) do |server|
      spawn do
        Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context, hostname: "example.com") do |socket|
          socket.alpn_protocol.should eq("h2")
        end
      end

      client = server.accept
      client.alpn_protocol.should eq("h2")
      client.close
    end
  end

  it "accepts clients that only write then close the connection" do
    tcp_server = TCPServer.new("127.0.0.1", 0)
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
    tcp_server = TCPServer.new("127.0.0.1", 0)
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
    tcp_server = TCPServer.new("127.0.0.1", 0)
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
