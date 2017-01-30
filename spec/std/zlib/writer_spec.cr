require "spec"
require "zlib"

module Zlib
  describe Writer do
    it "should be able to write" do
      message = "this is a test string !!!!\n"
      io = IO::Memory.new

      writer = Writer.new(io)

      io.bytesize.should eq(0)
      writer.flush
      io.bytesize.should_not eq(0)

      writer.print message
      writer.close

      io.rewind
      reader = Reader.new(io)
      reader.gets_to_end.should eq(message)
    end

    it "can be closed without sync" do
      io = IO::Memory.new
      writer = Writer.new(io)
      writer.close
      writer.closed?.should be_true
      io.closed?.should be_false

      expect_raises IO::Error, "Closed stream" do
        writer.print "a"
      end
    end

    it "can be closed with sync (1)" do
      io = IO::Memory.new
      writer = Writer.new(io, sync_close: true)
      writer.close
      writer.closed?.should be_true
      io.closed?.should be_true
    end

    it "can be closed with sync (2)" do
      io = IO::Memory.new
      writer = Writer.new(io)
      writer.sync_close = true
      writer.close
      writer.closed?.should be_true
      io.closed?.should be_true
    end

    it "can be flushed" do
      io = IO::Memory.new
      writer = Writer.new(io)

      writer.print "this"
      io.to_slice.hexstring.should eq("789c")

      writer.flush
      (io.to_slice.hexstring.size > 4).should be_true

      writer.print " is a test string !!!!\n"
      writer.close

      io.rewind
      reader = Reader.new(io)
      reader.gets_to_end.should eq("this is a test string !!!!\n")
    end
  end
end
