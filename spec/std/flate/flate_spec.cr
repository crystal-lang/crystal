require "spec"
require "flate"

module Flate
  describe Reader do
    it "should read byte by byte (#4192)" do
      io = IO::Memory.new
      "cbc9cc4b350402ae1c20c30808b800".scan(/../).each do |match|
        io.write_byte match[0].to_u8(16)
      end
      io.rewind

      reader = Reader.new(io)

      str = String::Builder.build do |builder|
        while b = reader.read_byte
          builder.write_byte b
        end
      end

      str.should eq("line1111\nline2222\n")
    end
  end

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
