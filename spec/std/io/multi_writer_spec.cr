require "spec"

describe "IO::MultiWriter" do
  describe "#write" do
    it "writes to multiple IOs" do
      io1 = IO::Memory.new
      io2 = IO::Memory.new

      writer = IO::MultiWriter.new(io1, io2)

      writer.puts "foo bar"

      io1.to_s.should eq("foo bar\n")
      io2.to_s.should eq("foo bar\n")
    end
  end

  describe "#read" do
    it "raises" do
      writer = IO::MultiWriter.new(Array(IO).new)

      expect_raises(IO::Error, "Can't read from IO::MultiWriter") do
        writer.read_byte
      end
    end
  end

  describe "#close" do
    it "stops reading" do
      io = IO::Memory.new
      writer = IO::MultiWriter.new(io)

      writer.close

      expect_raises(IO::Error, "Closed") do
        writer.puts "foo"
      end

      io.closed?.should eq(false)
      io.to_s.should eq("")
    end

    it "closes the underlying stream if sync_close is true" do
      io = IO::Memory.new
      writer = IO::MultiWriter.new(io, sync_close: true)

      writer.close

      io.closed?.should eq(true)
    end
  end
end
