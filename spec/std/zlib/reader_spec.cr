require "spec"
require "zlib"

module Zlib
  describe Reader do
    it "should be able to read" do
      io = IO::Memory.new
      "789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b".scan(/../).each do |match|
        io.write_byte match[0].to_u8(16)
      end
      io.rewind

      reader = Reader.new(io)

      str = String::Builder.build do |builder|
        IO.copy(reader, builder)
      end

      str.should eq("this is a test string !!!!\n")
      reader.read(Bytes.new(10)).should eq(0)
    end

    it "can be closed without sync" do
      io = IO::Memory.new(Bytes[120, 156, 3, 0, 0, 0, 0, 1])
      reader = Reader.new(io)
      reader.close
      reader.closed?.should be_true
      io.closed?.should be_false

      expect_raises IO::Error, "Closed stream" do
        reader.gets
      end
    end

    it "can be closed with sync (1)" do
      io = IO::Memory.new(Bytes[120, 156, 3, 0, 0, 0, 0, 1])
      reader = Reader.new(io, sync_close: true)
      reader.close
      reader.closed?.should be_true
      io.closed?.should be_true
    end

    it "can be closed with sync (2)" do
      io = IO::Memory.new(Bytes[120, 156, 3, 0, 0, 0, 0, 1])
      reader = Reader.new(io)
      reader.sync_close = true
      reader.close
      reader.closed?.should be_true
      io.closed?.should be_true
    end

    it "should not read from empty stream" do
      io = IO::Memory.new(Bytes[120, 156, 3, 0, 0, 0, 0, 1])
      reader = Reader.new(io)
      reader.read_byte.should be_nil
    end

    it "should not freeze when reading empty slice" do
      io = IO::Memory.new
      "789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b".scan(/../).each do |match|
        io.write_byte match[0].to_u8(16)
      end
      io.rewind
      reader = Reader.new(io)
      slice = Bytes.empty
      reader.read(slice).should eq(0)
    end
  end
end
