require "spec"
require "zlib"

module Zlib
  describe Deflate do
    it "should be able to deflate" do
      message = "this is a test string !!!!\n"
      io = IO::Memory.new
      deflate = Deflate.new(io)
      deflate.print message
      deflate.close

      io.rewind
      inflate = Inflate.new(io)
      inflate.gets_to_end.should eq(message)
    end

    it "can be closed without sync" do
      io = IO::Memory.new
      deflate = Deflate.new(io)
      deflate.close
      deflate.closed?.should be_true
      io.closed?.should be_false

      expect_raises IO::Error, "closed stream" do
        deflate.print "a"
      end
    end

    it "can be closed with sync (1)" do
      io = IO::Memory.new
      deflate = Deflate.new(io, sync_close: true)
      deflate.close
      deflate.closed?.should be_true
      io.closed?.should be_true
    end

    it "can be closed with sync (2)" do
      io = IO::Memory.new
      deflate = Deflate.new(io)
      deflate.sync_close = true
      deflate.close
      deflate.closed?.should be_true
      io.closed?.should be_true
    end

    it "can be flushed" do
      io = IO::Memory.new
      deflate = Deflate.new(io)

      deflate.print "this"
      io.to_slice.hexstring.should eq("789c")

      deflate.flush
      (io.to_slice.hexstring.size > 4).should be_true

      deflate.print " is a test string !!!!\n"
      deflate.close

      io.rewind
      inflate = Inflate.new(io)
      inflate.gets_to_end.should eq("this is a test string !!!!\n")
    end
  end
end
