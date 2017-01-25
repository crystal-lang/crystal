require "spec"
require "flate"

module Flate
  describe Writer do
    it "should be able to write" do
      message = "this is a test string !!!!\n"
      io = IO::Memory.new
      writer = Writer.new(io)
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
  end
end
