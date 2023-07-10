require "./spec_helper"
require "../spec_helper"
require "http/web_socket"
require "http/server"
require "random/secure"
require "../../support/fibers"
require "../../support/ssl"
require "../socket/spec_helper.cr"

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

private class MalformerHandler
  include HTTP::Handler

  def call(context)
    context.response.headers["Transfer-Encoding"] = "chunked"
    call_next(context)
  end
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
      data = File.read(datapath("websocket_longpacket.bin"))
      io = IO::Memory.new(data)
      ws = HTTP::WebSocket::Protocol.new(io)

      buffer = Bytes.new(2048)

      result = ws.receive(buffer)
      assert_text_packet result, 1023, final: true
      String.new(buffer[0, 1023]).should eq("x" * 1023)
    end

    it "read very long packet" do
      data = Bytes.new(10 + 0x010000)

      header = Bytes[0x82, 127_u8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]
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
      big_string = "abcdefghijklmnopqrstuvwxyz" * (IO::DEFAULT_BUFFER_SIZE // 4)
      size = big_string.size
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
        bytes[10 + i].should eq(big_string[i].ord)
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
      (first_frame[0] & 0x80).should eq(0x00) # FINAL bit unset
      (first_frame[0] & 0x0f).should eq(0x02) # BINARY frame
      first_frame[1].should eq(126)           # extended size
      received_size = 0
      2.times { |i| received_size <<= 8; received_size += first_frame[2 + i] }
      received_size.should eq(1024)
      received_size.times do |i|
        bytes[4 + i].should eq('a'.ord)
      end

      (second_frame[0] & 0x80).should_not eq(0x00) # FINAL bit set
      (second_frame[0] & 0x0f).should eq(0x00)     # CONTINUATION frame
      second_frame[1].should eq(126)               # extended size
      received_size = 0
      2.times { |i| received_size <<= 8; received_size += second_frame[2 + i] }
      received_size.should eq(512)
      received_size.times do |i|
        bytes[4 + i].should eq('a'.ord)
      end
    end

    it "sends less data than the frame size if necessary" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.stream do |io| # default frame size of 1024
        io.write("hello world".to_slice)
      end

      bytes = io.to_slice
      bytes.size.should eq(2 + 11) # one frame with 1 byte header, 1 byte size, "hello world" bytes content in total
      first_frame = bytes
      (first_frame[0] & 0x80).should_not eq(0x00) # FINAL bit set
      (first_frame[0] & 0x0f).should eq(0x02)     # BINARY frame
      first_frame[1].should eq(11)                # non-extended size
      (bytes + 2).should eq "hello world".to_slice
    end

    it "sets opcode of first frame to binary if stream is called with binary = true" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.stream(binary: true) { |io| }

      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x02) # BINARY frame
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
      big_string = "abcdefghijklmnopqrstuvwxyz" * (IO::DEFAULT_BUFFER_SIZE // 4)
      size = big_string.size
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
        (bytes[14 + i] ^ bytes[10 + (i % 4)]).should eq(big_string[i].ord)
      end
    end
  end

  describe "close" do
    it "closes with code" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.close(4020)
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x08) # CLOSE frame
      bytes[1].should eq(0x02)          # 2 bytes code
      bytes[2].should eq(0x0f)
      bytes[3].should eq(0xb4)
    end

    it "closes with message" do
      message = "bye"
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.close(nil, message)
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x08) # CLOSE frame
      bytes[1].should eq(0x05)          # 2 + message.bytesize
      bytes[2].should eq(0x03)
      bytes[3].should eq(0xe8)
      String.new(bytes[4..6]).should eq(message)
    end

    it "closes with message and code" do
      message = "4020"
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.close(4020, message)
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x08) # CLOSE frame
      bytes[1].should eq(0x06)          # 2 + message.bytesize
      bytes[2].should eq(0x0f)
      bytes[3].should eq(0xb4)
      String.new(bytes[4..7]).should eq(message)
    end

    it "closes without message" do
      io = IO::Memory.new
      ws = HTTP::WebSocket::Protocol.new(io)
      ws.close
      bytes = io.to_slice
      (bytes[0] & 0x0f).should eq(0x08) # CLOSE frame
      bytes[1].should eq(0x00)
    end
  end

  each_ip_family do |family, local_address|
    it "negotiates over HTTP correctly" do
      address_chan = Channel(Socket::IPAddress).new
      close_chan = Channel({Int32, String}).new

      f = spawn do
        http_ref = nil
        ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
          ctx.request.path.should eq("/foo/bar")
          ctx.request.query_params["query"].should eq("arg")
          ctx.request.query_params["yes"].should eq("please")

          ws.on_message do |str|
            ws.send("pong #{str}")
          end

          ws.on_close do |code, message|
            http_ref.not_nil!.close
            close_chan.send({code.to_i, message})
          end
        end

        http_server = http_ref = HTTP::Server.new([ws_handler])
        address = http_server.bind_tcp(local_address, 0)
        address_chan.send(address)
        http_server.listen
      end

      listen_address = address_chan.receive
      wait_until_blocked f

      ws2 = HTTP::WebSocket.new("ws://#{listen_address}/foo/bar?query=arg&yes=please")

      random = Random::Secure.hex
      ws2.on_message do |str|
        str.should eq("pong #{random}")
        ws2.close(4020, "close message")
      end
      ws2.send(random)

      ws2.run

      code, message = close_chan.receive
      code.should eq(4020)
      message.should eq("close message")
    end

    it "negotiates over HTTPS correctly" do
      address_chan = Channel(Socket::IPAddress).new

      server_context, client_context = ssl_context_pair

      f = spawn do
        http_ref = nil
        ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
          ctx.request.path.should eq("/")

          ws.on_message do |str|
            ws.send("pong #{str}")
            ws.close
          end

          ws.on_close do
            http_ref.not_nil!.close
          end
        end

        http_server = http_ref = HTTP::Server.new([ws_handler])

        address = http_server.bind_tls(local_address, context: server_context)
        address_chan.send(address)
        http_server.listen
      end

      listen_address = address_chan.receive
      wait_until_blocked f

      ws2 = HTTP::WebSocket.new(listen_address.address, port: listen_address.port, path: "/", tls: client_context)

      random = Random::Secure.hex
      ws2.on_message do |str|
        str.should eq("pong #{random}")
      end
      ws2.send(random)

      ws2.run
    end
  end

  it "sends correct HTTP basic auth header" do
    ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
      ws.send ctx.request.headers["Authorization"]
      ws.close
    end
    http_server = HTTP::Server.new([ws_handler])
    address = http_server.bind_unused_port

    run_server(http_server) do
      client = HTTP::WebSocket.new("ws://test_username:test_password@#{address}")
      message = nil
      client.on_message do |msg|
        message = msg
      end
      client.run
      message.should eq(
        "Basic #{Base64.strict_encode("test_username:test_password")}")
    end
  end

  it "handshake fails if server does not switch protocols" do
    http_server = HTTP::Server.new do |context|
      context.response.status_code = 200
    end

    address = http_server.bind_unused_port

    run_server(http_server) do
      expect_raises(Socket::Error, "Handshake got denied. Status code was 200.") do
        HTTP::WebSocket::Protocol.new(address.address, port: address.port, path: "/")
      end
    end
  end

  it "ignores body in upgrade response (malformed)" do
    malformer = MalformerHandler.new
    ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
      ws.on_message do |str|
        ws.send(str)
      end
    end
    http_server = HTTP::Server.new([malformer, ws_handler])

    address = http_server.bind_unused_port

    run_server(http_server) do
      client = HTTP::WebSocket.new("ws://#{address}")
      message = nil
      client.on_message do |msg|
        message = msg
        client.close
      end
      client.send "hello"
      client.run
      message.should eq("hello")
    end
  end

  it "doesn't compress upgrade response body" do
    compress_handler = HTTP::CompressHandler.new
    ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
      ws.on_message do |str|
        ws.send(str)
      end
    end
    http_server = HTTP::Server.new([compress_handler, ws_handler])

    address = http_server.bind_unused_port

    run_server(http_server) do
      client = HTTP::WebSocket.new("ws://#{address}", headers: HTTP::Headers{"Accept-Encoding" => "gzip"})
      message = nil
      client.on_message do |msg|
        message = msg
        client.close
      end
      client.send "hello"
      client.run
      message.should eq("hello")
    end
  end

  describe "handshake fails if server does not verify Sec-WebSocket-Key" do
    it "Sec-WebSocket-Accept missing" do
      http_server = HTTP::Server.new do |context|
        response = context.response
        response.status_code = 101
        response.headers["Upgrade"] = "websocket"
        response.headers["Connection"] = "Upgrade"
      end

      address = http_server.bind_unused_port

      run_server(http_server) do
        expect_raises(Socket::Error, "Handshake got denied. Server did not verify WebSocket challenge.") do
          HTTP::WebSocket::Protocol.new(address.address, port: address.port, path: "/")
        end
      end
    end

    it "Sec-WebSocket-Accept incorrect" do
      http_server = HTTP::Server.new do |context|
        response = context.response
        response.status_code = 101
        response.headers["Upgrade"] = "websocket"
        response.headers["Connection"] = "Upgrade"
        response.headers["Sec-WebSocket-Accept"] = "foobar"
      end

      address = http_server.bind_unused_port

      run_server(http_server) do
        expect_raises(Socket::Error, "Handshake got denied. Server did not verify WebSocket challenge.") do
          HTTP::WebSocket::Protocol.new(address.address, port: address.port, path: "/")
        end
      end
    end
  end

  typeof(HTTP::WebSocket.new(URI.parse("ws://localhost")))
  typeof(HTTP::WebSocket.new("localhost", "/"))
  typeof(HTTP::WebSocket.new("ws://localhost"))
  typeof(HTTP::WebSocket.new(URI.parse("ws://localhost"), headers: HTTP::Headers{"X-TEST_HEADER" => "some-text"}))
end

private def integration_setup(&)
  bin_ch = Channel(Bytes).new
  txt_ch = Channel(String).new
  ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
    ws.on_binary { |bytes| bin_ch.send bytes }
    ws.on_message { |bytes| txt_ch.send bytes }
  end
  server = HTTP::Server.new [ws_handler]
  address = server.bind_unused_port
  spawn server.listen
  wsoc = HTTP::WebSocket.new("http://#{address}")

  yield wsoc, bin_ch, txt_ch
ensure
  server.close if server
end

describe "Websocket integration tests" do
  # default frame size is 1024, but be explicit here in case the default changes in the future

  it "streams less than the buffer frame size" do
    integration_setup do |wsoc, bin_ch, _|
      bytes = "hello test world".to_slice
      wsoc.stream(frame_size: 1024, &.write(bytes))
      received = bin_ch.receive
      received.should eq bytes
    end
  end

  it "streams single messages more than the buffer frame size" do
    integration_setup do |wsoc, bin_ch, _|
      bytes = ("hello test world" * 80).to_slice
      bytes.size.should be > 1024
      wsoc.stream(frame_size: 1024, &.write(bytes))
      received = bin_ch.receive
      received.should eq bytes
    end
  end

  it "streams single messages made up of multiple parts that eventually become more than the buffer frame size" do
    integration_setup do |wsoc, bin_ch, _|
      bytes = "hello test world".to_slice
      wsoc.stream(frame_size: 1024) { |io| 80.times { io.write bytes } }
      received = bin_ch.receive
      received.size.should be > 1024
      received.should eq ("hello test world" * 80).to_slice
    end
  end

  it "sends single text messages" do
    integration_setup do |wsoc, _, txt_ch|
      wsoc.send "hello text"
      wsoc.send "hello again"
      txt_ch.receive.should eq "hello text"
      txt_ch.receive.should eq "hello again"
    end
  end
end
