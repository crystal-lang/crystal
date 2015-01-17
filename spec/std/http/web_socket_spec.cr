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
  end
end
