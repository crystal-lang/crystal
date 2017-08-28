require "spec"
require "http/web_socket"
require "random/secure"

private def assert_text_packet(packet, size, final = false)
  assert_packet packet, HTTP::WebSocket::Protocol::Opcode::TEXT, size, final: final
end

private def assert_binary_packet(packet, size, final = false)
  assert_packet packet, HTTP::WebSocket::Protocol::Opcode::BINARY, size, final: final
end

private def assert_ping_packet(packet, size, final = false)
  assert_packet packet, HTTP::WebSocket::Protocol::Opcode::PING, size, final: final
end

private def assert_close_packet(packet, size, final = false)
  assert_packet packet, HTTP::WebSocket::Protocol::Opcode::CLOSE, size, final: final
end

private def assert_packet(packet, opcode, size, final = false)
  packet.opcode.should eq(opcode)
  packet.size.should eq(size)
  packet.final.should eq(final)
end

describe HTTP::WebSocket do
  describe "receive" do
    it "can read a small text packet" do
      data = Bytes[0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(64)
      result = ws.receive(buffer)
      assert_text_packet result, 5, final: true
      String.new(buffer[0, result.size]).should eq("Hello")
    end

    it "can read partial packets" do
      data = Bytes[0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f,
        0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(3)

      2.times do
        result = ws.receive(buffer)
        assert_text_packet result, 3, final: false
        String.new(buffer).should eq("Hel")

        result = ws.receive(buffer)
        assert_text_packet result, 2, final: true
        String.new(buffer[0, 2]).should eq("lo")
      end
    end

    it "can read masked text message" do
      data = Bytes[0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58,
        0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58]
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(3)

      2.times do
        result = ws.receive(buffer)
        assert_text_packet result, 3, final: false
        String.new(buffer).should eq("Hel")

        result = ws.receive(buffer)
        assert_text_packet result, 2, final: true
        String.new(buffer[0, 2]).should eq("lo")
      end
    end

    it "can read fragmented packets" do
      data = Bytes[0x01, 0x03, 0x48, 0x65, 0x6c, 0x80, 0x02, 0x6c, 0x6f,
        0x01, 0x03, 0x48, 0x65, 0x6c, 0x80, 0x02, 0x6c, 0x6f]

      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(10)

      2.times do
        result = ws.receive(buffer)
        assert_text_packet result, 3, final: false
        String.new(buffer[0, 3]).should eq("Hel")

        result = ws.receive(buffer)
        assert_text_packet result, 2, final: true
        String.new(buffer[0, 2]).should eq("lo")
      end
    end

    it "read ping packet" do
      data = Bytes[0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(64)
      result = ws.receive(buffer)
      assert_ping_packet result, 5, final: true
      String.new(buffer[0, result.size]).should eq("Hello")
    end

    it "read ping packet in between fragmented packet" do
      data = Bytes[0x01, 0x03, 0x48, 0x65, 0x6c,
        0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f,
        0x80, 0x02, 0x6c, 0x6f]
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(64)

      result = ws.receive(buffer)
      assert_text_packet result, 3, final: false
      String.new(buffer[0, 3]).should eq("Hel")

      result = ws.receive(buffer)
      assert_ping_packet result, 5, final: true
      String.new(buffer[0, result.size]).should eq("Hello")

      result = ws.receive(buffer)
      assert_text_packet result, 2, final: true
      String.new(buffer[0, 2]).should eq("lo")
    end

    it "read long packet" do
      data = File.read("#{__DIR__}/../data/websocket_longpacket.bin")
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(2048)

      result = ws.receive(buffer)
      assert_text_packet result, 1023, final: true
      String.new(buffer[0, 1023]).should eq("x" * 1023)
    end

    it "read very long packet" do
      data = Bytes.new(10 + 0x010000)

      header = Bytes[0x82, 127_u8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x0]
      data.copy_from(header)

      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(0x010000)

      result = ws.receive(buffer)
      assert_binary_packet result, 0x010000, final: true
    end

    it "can read a close packet" do
      data = Bytes[0x88, 0x00]
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(64)
      result = ws.receive(buffer)
      assert_close_packet result, 0, final: true
    end
  end

  describe "send" do
    it "sends long data with correct header" do
      size = UInt16::MAX.to_u64 + 1
      big_string = "a" * size
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.send(big_string)
      bytes = io.to_slice
      bytes.size.should eq(10 + size) # 2 bytes header, 8 bytes size, UInt16 + 1 bytes content
      bytes[1].should eq(127)
      received_size = 0
      8.times { |i| received_size <<= 8; received_size += bytes[2 + i] }
      received_size.should eq(size)
      size.times do |i|
        bytes[10 + i].should eq('a'.ord)
      end
    end

    it "sets binary opcode if used with slice" do
      sent_bytes = uninitialized UInt8[4]

      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io, masked: true)
      ws.send(sent_bytes.to_slice)
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x02)
    end
  end

  describe "stream" do
    it "sends continuous data and splits it to frames" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.stream do |io| # default frame size of 1024
        3.times { io.write(("a" * 512).to_slice) }
      end

      bytes = io.to_slice
      bytes.size.should eq(4 * 2 + 512 * 3) # two frames with 2 bytes header, 2 bytes size, 3 * 512 bytes content in total
      first_frame, second_frame = {bytes[0, (4 + 1024)], bytes + (4 + 1024)}
      (first_frame[0] & 0x80).should eq(0)   # FINAL bit unset
      (first_frame[0] & 0x0f).should eq(0x2) # BINARY frame
      first_frame[1].should eq(126)          # extended size
      received_size = 0
      2.times { |i| received_size <<= 8; received_size += first_frame[2 + i] }
      received_size.should eq(1024)
      received_size.times do |i|
        bytes[4 + i].should eq('a'.ord)
      end

      (second_frame[0] & 0x80).should_not eq(0) # FINAL bit set
      (second_frame[0] & 0x0f).should eq(0x0)   # CONTINUATION frame
      second_frame[1].should eq(126)            # extended size
      received_size = 0
      2.times { |i| received_size <<= 8; received_size += second_frame[2 + i] }
      received_size.should eq(512)
      received_size.times do |i|
        bytes[4 + i].should eq('a'.ord)
      end
    end

    it "sets opcode of first frame to binary if stream is called with binary = true" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.stream(binary: true) { |io| }

      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x2) # BINARY frame
    end
  end

  describe "send_masked" do
    it "sends the data with a bitmask" do
      sent_string = "hello"
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io, masked: true)
      ws.send(sent_string)
      bytes = io.to_slice
      bytes.size.should eq(11)     # 2 bytes header, 4 bytes mask, 5 bytes content
      bytes[1].bit(7).should eq(1) # For mask bit
      (bytes[1] - 128).should eq(sent_string.size)
      (bytes[2] ^ bytes[6]).should eq('h'.ord)
      (bytes[3] ^ bytes[7]).should eq('e'.ord)
      (bytes[4] ^ bytes[8]).should eq('l'.ord)
      (bytes[5] ^ bytes[9]).should eq('l'.ord)
      (bytes[2] ^ bytes[10]).should eq('o'.ord)
    end

    it "sends long data with correct header" do
      size = UInt16::MAX.to_u64 + 1
      big_string = "a" * size
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io, masked: true)
      ws.send(big_string)
      bytes = io.to_slice
      bytes.size.should eq(size + 14) # 2 bytes header, 8 bytes size, 4 bytes mask, UInt16::MAX + 1 bytes content
      bytes[1].bit(7).should eq(1)    # For mask bit
      (bytes[1] - 128).should eq(127)
      received_size = 0
      8.times { |i| received_size <<= 8; received_size += bytes[2 + i] }
      received_size.should eq(size)
      size.times do |i|
        (bytes[14 + i] ^ bytes[10 + (i % 4)]).should eq('a'.ord)
      end
    end
  end

  describe "close" do
    it "closes with message" do
      message = "bye"
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.close(message)
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x8) # CLOSE frame
      String.new(bytes[2, bytes[1]]).should eq(message)
    end

    it "closes without message" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.close
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x8) # CLOSE frame
      bytes[1].should eq(0)
    end
  end

  it "negotiates over HTTP correctly" do
    port_chan = Channel(Int32).new

    spawn do
      http_ref = nil
      ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
        ctx.request.path.should eq("/")

        ws.on_message do |str|
          ws.send("pong #{str}")
        end

        ws.on_close do
          http_ref.not_nil!.close
        end
      end

      http_server = http_ref = HTTP::Server.new(0, [ws_handler])
      http_server.bind
      port_chan.send(http_server.port)
      http_server.listen
    end

    listen_port = port_chan.receive

    ws2 = HTTP::WebSocket.new("ws://127.0.0.1:#{listen_port}")

    random = Random::Secure.hex
    ws2.on_message do |str|
      str.should eq("pong #{random}")
      ws2.close
    end
    ws2.send(random)

    ws2.run
  end

  it "negotiates over HTTPS correctly" do
    port_chan = Channel(Int32).new

    spawn do
      http_ref = nil
      ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
        ctx.request.path.should eq("/")

        ws.on_message do |str|
          ws.send("pong #{str}")
        end

        ws.on_close do
          http_ref.not_nil!.close
        end
      end

      http_server = http_ref = HTTP::Server.new(0, [ws_handler])
      tls = http_server.tls = OpenSSL::SSL::Context::Server.new
      tls.certificate_chain = File.join(__DIR__, "../openssl/ssl/openssl.crt")
      tls.private_key = File.join(__DIR__, "../openssl/ssl/openssl.key")
      http_server.bind
      port_chan.send(http_server.port)
      http_server.listen
    end

    listen_port = port_chan.receive

    client_context = OpenSSL::SSL::Context::Client.insecure
    ws2 = HTTP::WebSocket.new("127.0.0.1", port: listen_port, path: "/", tls: client_context)

    random = Random::Secure.hex
    ws2.on_message do |str|
      str.should eq("pong #{random}")
      ws2.close
    end
    ws2.send(random)

    ws2.run
  end

  typeof(HTTP::WebSocket.new(URI.parse("ws://localhost")))
  typeof(HTTP::WebSocket.new("localhost", "/"))
  typeof(HTTP::WebSocket.new("ws://localhost"))
  typeof(HTTP::WebSocket.new(URI.parse("ws://localhost"), headers: HTTP::Headers{"X-TEST_HEADER" => "some-text"}))
end
