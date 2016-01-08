require "spec"
require "zlib"

module Zlib
  describe Inflate do
    it "should be able to inflate" do
      io = MemoryIO.new
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

    it "can be closed" do
      io = MemoryIO.new("")
      deflate = Inflate.new(io)
      deflate.close
      io.closed?.should be_true
    end
  end
end
