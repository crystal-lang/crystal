require "spec"
require "zlib"

module Zlib
  describe Inflate do
    it "should be able to inflate" do
      io = IO::Memory.new
      "789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b".scan(/../).each do |match|
        io.write_byte match[0].to_u8(16)
      end
      io.rewind

      inflate = Inflate.new(io)

      str = String::Builder.build do |builder|
        IO.copy(inflate, builder)
      end

      str.should eq("this is a test string !!!!\n")
      inflate.read(Slice(UInt8).new(10)).should eq(0)
    end

    it "can be closed without sync" do
      io = IO::Memory.new("")
      inflate = Inflate.new(io)
      inflate.close
      inflate.closed?.should be_true
      io.closed?.should be_false

      expect_raises IO::Error, "closed stream" do
        inflate.gets
      end
    end

    it "can be closed with sync (1)" do
      io = IO::Memory.new("")
      inflate = Inflate.new(io, sync_close: true)
      inflate.close
      inflate.closed?.should be_true
      io.closed?.should be_true
    end

    it "can be closed with sync (2)" do
      io = IO::Memory.new("")
      inflate = Inflate.new(io)
      inflate.sync_close = true
      inflate.close
      inflate.closed?.should be_true
      io.closed?.should be_true
    end

    it "should not inflate from empty stream" do
      io = IO::Memory.new("")
      inflate = Inflate.new(io)
      inflate.read_byte.should be_nil
    end

    it "should not freeze when reading empty slice" do
      io = IO::Memory.new
      "789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b".scan(/../).each do |match|
        io.write_byte match[0].to_u8(16)
      end
      io.rewind
      inflate = Inflate.new(io)
      slice = Slice(UInt8).new(0)
      inflate.read(slice).should eq(0)
    end
  end
end
