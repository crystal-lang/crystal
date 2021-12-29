require "spec"
require "compress/zlib"

private def new_sample_io
  io = IO::Memory.new
  "789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b".scan(/../).each do |match|
    io.write_byte match[0].to_u8(16)
  end
  io.rewind
end

module Compress::Zlib
  describe Reader do
    it "should be able to read" do
      io = new_sample_io

      reader = Reader.new(io)

      str = String::Builder.build do |builder|
        IO.copy(reader, builder)
      end

      str.should eq("this is a test string !!!!\n")
      reader.read(Bytes.new(10)).should eq(0)
    end

    it "rewinds" do
      io = new_sample_io

      reader = Reader.new(io)
      reader.gets(3).should eq("thi")
      reader.rewind
      reader.gets_to_end.should eq("this is a test string !!!!\n")
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
      io = new_sample_io
      reader = Reader.new(io)
      slice = Bytes.empty
      reader.read(slice).should eq(0)
    end

    it "should raise buffer error on error (#6575)" do
      io = IO::Memory.new("x\x9C4\xC9\xD1\n@@\u0010\u0005\xD0\u007F\xB9ϻeEj~E\xD2`B\xAD\xA55H\x9B\u007F\xE7\xC5۩\x93\xA0\xA0pxo\xB0\xFFX7\x90\xCB\f\u0006P\xC2$\u001C\xB5\u0013\xD6v\u000E*\xF1d\u000F*\\^~\xDFj\xE4^@5FV\xB9\xF8\xB6[\u001C\xEC\xC2s\xB0\x99\xD3\n\xCD\xF3\xBC\u0000\u0000\u0000\xFF\xFF")

      reader = Reader.new(io)

      expect_raises(Compress::Deflate::Error, "deflate: buffer error") do
        reader.gets_to_end
      end
    end
  end
end
