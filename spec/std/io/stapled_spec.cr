require "spec"

describe IO::Stapled do
  it "combines two IOs" do
    writer = IO::Memory.new
    io = IO::Stapled.new IO::Memory.new("paul"), writer
    io.gets.should eq "paul"
    io << "peter"
    writer.to_s.should eq "peter"
  end

  it "loops back" do
    io = IO::Stapled.new(*IO.pipe)
    io.puts "linus"
    io.gets.should eq "linus"
  end

  describe "#close" do
    it "does not close underlying IOs" do
      reader, writer = IO::Memory.new, IO::Memory.new
      io = IO::Stapled.new reader, writer
      io.refute &.sync_close?
      io.close
      io.assert &.closed?
      reader.refute &.closed?
      writer.refute &.closed?
    end

    it "closes underlying IOs when sync_close is true" do
      reader, writer = IO::Memory.new, IO::Memory.new
      io = IO::Stapled.new reader, writer, sync_close: true
      io.assert &.sync_close?
      io.close
      io.assert &.closed?
      reader.assert &.closed?
      writer.assert &.closed?
    end

    it "stops access to underlying IOs" do
      reader, writer = IO::Memory.new("cle"), IO::Memory.new
      io = IO::Stapled.new reader, writer
      io.close
      io.assert &.closed?
      reader.refute &.closed?
      writer.refute &.closed?

      expect_raises(IO::Error, "Closed stream") do
        io.gets
      end
      expect_raises(IO::Error, "Closed stream") do
        io.peek
      end
      expect_raises(IO::Error, "Closed stream") do
        io << "closed"
      end
    end
  end

  it "#sync_close?" do
    reader, writer = IO::Memory.new, IO::Memory.new
    io = IO::Stapled.new reader, writer
    io.sync_close = false
    io.refute &.sync_close?
    io.sync_close = true
    io.assert &.sync_close?
    io.close
    reader.assert &.closed?
    writer.assert &.closed?
  end

  it "#peek delegates to reader" do
    reader = IO::Memory.new "cletus"
    io = IO::Stapled.new reader, IO::Memory.new
    io.peek.should eq "cletus".to_slice
    io.gets
    io.peek.should eq Bytes.empty
  end

  it "#skip delegates to reader" do
    reader = IO::Memory.new "cletus"
    io = IO::Stapled.new reader, IO::Memory.new
    io.peek.should eq "cletus".to_slice
    io.skip(4)
    io.peek.should eq "us".to_slice
  end

  it "#skip_to_end delegates to reader" do
    reader = IO::Memory.new "cletus"
    io = IO::Stapled.new reader, IO::Memory.new
    io.peek.should eq "cletus".to_slice
    io.skip_to_end
    io.peek.should eq Bytes.empty
  end

  describe ".pipe" do
    it "creates a bidirectional pipe" do
      a, b = IO::Stapled.pipe
      begin
        a.assert &.sync_close?
        b.assert &.sync_close?
        a.puts "john"
        b.gets.should eq "john"
        b.puts "paul"
        a.gets.should eq "paul"
      ensure
        a.close
        b.close
      end
    end

    it "with block creates a bidirectional pipe" do
      ext_a, ext_b = nil, nil
      IO::Stapled.pipe do |a, b|
        ext_a, ext_b = a, b
        a.assert &.sync_close?
        b.assert &.sync_close?
        a.puts "john"
        b.gets.should eq "john"
        b.puts "paul"
        a.gets.should eq "paul"
        a.sync_close = false
        b.sync_close = false
      end
      ext_a.not_nil!.assert &.closed?
      ext_b.not_nil!.assert &.closed?
    end
  end
end
