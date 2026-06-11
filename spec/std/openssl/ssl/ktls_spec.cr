require "../../spec_helper"
require "../../../support/ssl"

{% skip_file unless OpenSSL.has_constant?(:KTLS) %}

# Regression spec for #16881.
#
# Since kTLS bypasses the transport, records are read straight from the
# kernel, we need to ensure there's no data that can get "stuck" in
# buffers as we switch from userspace to kernel.
#
# There's some timing involved thus opening many connections to provoke it.
describe "OpenSSL::SSL::Socket (kTLS)" do
  it "delivers data sent immediately after the handshake" do
    server_context, client_context = ssl_context_pair
    server_context.add_options(OpenSSL::SSL::Options::ENABLE_KTLS)

    TCPServer.open("127.0.0.1", 0) do |tcp_server|
      address = tcp_server.local_address
      n = 100
      served = Channel(Bool).new(n)

      serve = ->(socket : TCPSocket) do
        begin
          ssl = OpenSSL::SSL::Socket::Server.new(socket, server_context, sync_close: true)
          if byte = ssl.read_byte
            ssl.write(Bytes[byte]) # echo so the client's read completes
            ssl.flush
          end
          served.send(byte == 42_u8)
        rescue
          served.send(false)
        ensure
          ssl.try(&.close)
        end
      end

      spawn do
        while client = tcp_server.accept?
          spawn serve.call(client)
        end
      end

      n.times do
        spawn do
          tcp = TCPSocket.new(address.address, address.port)
          ssl = OpenSSL::SSL::Socket::Client.new(tcp, client_context, sync_close: true)
          ssl.write(Bytes[42_u8])
          ssl.flush
          ssl.read_byte
        rescue
          # silence
        ensure
          ssl.try(&.close)
        end
      end

      collected = Channel(Int32).new(1)
      spawn do
        ok = 0
        n.times { ok += 1 if served.receive }
        collected.send(ok)
      end

      select
      when count = collected.receive
        count.should eq n
      when timeout(5.seconds)
        fail "timeout: data sent immediately after the handshake was not delivered"
      end
    end
  end
end
