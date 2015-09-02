require "spec"
require "http/web_socket"

private def packet(bytes)
  slice = Slice(UInt8).new(bytes.length) { |i| bytes[i].to_u8 }
  slice.pointer(bytes.length)
end

describe HTTP::WebSocket do
  describe "receive" do
    it "can read a small text packet" do
      data = packet([0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f])
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(64)
      result = ws.receive(buffer)
      result.type.should eq(:text)
      result.length.should eq(5)
      result.final?.should be_true
      String.new(buffer[0, result.length]).should eq("Hello")
    end

    it "can read partial packets" do
      data = packet([0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f,
                     0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f])
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(3)

      2.times do
        result = ws.receive(buffer)
        result.type.should eq(:text)
        result.length.should eq(3)
        result.final?.should be_false
        String.new(buffer).should eq("Hel")

        result = ws.receive(buffer)
        result.type.should eq(:text)
        result.length.should eq(2)
        result.final?.should be_true
        String.new(buffer[0, 2]).should eq("lo")
      end
    end

    it "can read masked text message" do
      data = packet([0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58,
                     0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58])
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(3)

      2.times do
        result = ws.receive(buffer)
        result.type.should eq(:text)
        result.length.should eq(3)
        result.final?.should be_false
        String.new(buffer).should eq("Hel")

        result = ws.receive(buffer)
        result.type.should eq(:text)
        result.length.should eq(2)
        result.final?.should be_true
        String.new(buffer[0, 2]).should eq("lo")
      end
    end

    it "can read fragmented packets" do
      data = packet([0x01, 0x03, 0x48, 0x65, 0x6c, 0x80, 0x02, 0x6c, 0x6f,
                     0x01, 0x03, 0x48, 0x65, 0x6c, 0x80, 0x02, 0x6c, 0x6f])

      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(10)

      2.times do
        result = ws.receive(buffer)
        result.type.should eq(:text)
        result.length.should eq(3)
        result.final?.should be_false
        String.new(buffer[0, 3]).should eq("Hel")

        result = ws.receive(buffer)
        result.type.should eq(:text)
        result.length.should eq(2)
        result.final?.should be_true
        String.new(buffer[0, 2]).should eq("lo")
      end
    end

    it "read ping packet" do
      data = packet([0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f])
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(64)
      result = ws.receive(buffer)
      result.type.should eq(:ping)
      result.length.should eq(5)
      result.final?.should be_true
      String.new(buffer[0, result.length]).should eq("Hello")
    end

    it "read ping packet in between fragmented packet" do
      data = packet([0x01, 0x03, 0x48, 0x65, 0x6c,
                     0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f,
                     0x80, 0x02, 0x6c, 0x6f])
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(64)

      result = ws.receive(buffer)
      result.type.should eq(:text)
      result.length.should eq(3)
      result.final?.should be_false
      String.new(buffer[0, 3]).should eq("Hel")

      result = ws.receive(buffer)
      result.type.should eq(:ping)
      result.length.should eq(5)
      result.final?.should be_true
      String.new(buffer[0, result.length]).should eq("Hello")

      result = ws.receive(buffer)
      result.type.should eq(:text)
      result.length.should eq(2)
      result.final?.should be_true
      String.new(buffer[0, 2]).should eq("lo")
    end

    it "read long packet" do
      data = File.read("#{__DIR__}/../data/websocket_longpacket.bin").cstr
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(2048)

      result = ws.receive(buffer)
      result.type.should eq(:text)
      result.length.should eq(1023)
      result.final?.should be_true
      String.new(buffer[0, 1023]).should eq("x" * 1023)
    end

    it "can read a close packet" do
      data = packet([0x88, 0x00])
      io = PointerIO.new(pointerof(data))
      ws = HTTP::WebSocket.new(io)

      buffer = Slice(UInt8).new(64)
      result = ws.receive(buffer)
      result.type.should eq(:close)
      result.length.should eq(0)
      result.final?.should be_true
    end
  end

  describe "send" do
     it "sends long data with correct header" do
       length = UInt16::MAX.to_u64 + 1
       big_string = "a" * length
       io = StringIO.new
       ws = HTTP::WebSocket.new(io)
       ws.send(big_string)
       bytes = io.to_slice
       bytes.length.should eq(6 + length) # 2 bytes header, 4 bytes length, UInt16 + 1 bytes content
       bytes[1].should eq(127)
       received_length = 0
       4.times { |i| received_length <<= 8; received_length += bytes[2 + i] }
       received_length.should eq(length)
       length.times do |i|
         bytes[6 + i].should eq('a'.ord)
       end
     end
  end

  describe "send_masked" do
    it "sends the data with a bitmask" do
      sent_string = "hello"
      io = StringIO.new
      ws = HTTP::WebSocket.new(io)
      ws.send_masked(sent_string)
      bytes = io.to_slice
      bytes.length.should eq(11) # 2 bytes header, 4 bytes mask, 5 bytes content
      bytes[1].bit(7).should eq(1) # For mask bit
      (bytes[1] - 128).should eq(sent_string.length)
      (bytes[2] ^ bytes[6]).should eq('h'.ord)
      (bytes[3] ^ bytes[7]).should eq('e'.ord)
      (bytes[4] ^ bytes[8]).should eq('l'.ord)
      (bytes[5] ^ bytes[9]).should eq('l'.ord)
      (bytes[2] ^ bytes[10]).should eq('o'.ord)
    end

    it "sends long data with correct header" do
      length = UInt16::MAX.to_u64 + 1
      big_string = "a" * length
      io = StringIO.new
      ws = HTTP::WebSocket.new(io)
      ws.send_masked(big_string)
      bytes = io.to_slice
      bytes.length.should eq(length + 10) # 2 bytes header, 4 bytes length, 4 bytes mask, UInt16::MAX + 1 bytes content
      bytes[1].bit(7).should eq(1) # For mask bit
      (bytes[1] - 128).should eq(127)
      received_length = 0
      4.times { |i| received_length <<= 8; received_length += bytes[2 + i] }
      received_length.should eq(length)
      length.times do |i|
        (bytes[10 + i] ^ bytes[6 + (i % 4)]).should eq('a'.ord)
      end
    end
  end
end
