require "spec"

private class PartialReaderIO
  include IO

  @slice : Bytes

  def initialize(data : String)
    @slice = data.to_slice
  end

  def read(slice : Bytes)
    return 0 if @slice.size == 0
    max_read_size = {slice.size, @slice.size}.min
    read_size = rand(1..max_read_size)
    slice.copy_from(@slice[0, read_size])
    @slice += read_size
    read_size
  end

  def write(slice : Bytes)
    raise "write"
  end
end

describe "IO::Delimited" do
  describe "#read" do
    it "doesn't read past the limit" do
      io = IO::Memory.new("abcderzzrfgzr")
      delimited = IO::Delimited.new(io, read_delimiter: "zr")

      delimited.gets_to_end.should eq("abcderz")
      io.gets_to_end.should eq("fgzr")
    end

    it "doesn't read past the limit (char-by-char)" do
      io = IO::Memory.new("abcderzzrfg")
      delimited = IO::Delimited.new(io, read_delimiter: "zr")

      delimited.read_char.should eq('a')
      delimited.read_char.should eq('b')
      delimited.read_char.should eq('c')
      delimited.read_char.should eq('d')
      delimited.read_char.should eq('e')
      delimited.read_char.should eq('r')
      delimited.read_char.should eq('z')
      delimited.read_char.should eq(nil)
      delimited.read_char.should eq(nil)
      delimited.read_char.should eq(nil)
      delimited.read_char.should eq(nil)

      io.read_char.should eq('f')
      io.read_char.should eq('g')
    end

    it "doesn't clobber active_delimiter_buffer" do
      io = IO::Memory.new("ab12312")
      delimited = IO::Delimited.new(io, read_delimiter: "12345")

      delimited.gets_to_end.should eq("ab12312")
    end

    it "handles the delimiter at the start" do
      io = IO::Memory.new("ab12312")
      delimited = IO::Delimited.new(io, read_delimiter: "ab1")

      delimited.read_char.should eq(nil)
    end

    it "handles the delimiter at the end" do
      io = IO::Memory.new("ab12312z")
      delimited = IO::Delimited.new(io, read_delimiter: "z")

      delimited.gets_to_end.should eq("ab12312")
    end

    it "handles nearly a delimiter at the end" do
      io = IO::Memory.new("ab12312")
      delimited = IO::Delimited.new(io, read_delimiter: "122")

      delimited.gets_to_end.should eq("ab12312")
    end

    it "doesn't clobber the buffer on closely-offset partial matches" do
      io = IO::Memory.new("abab1234abcdefgh")
      delimited = IO::Delimited.new(io, read_delimiter: "abcdefgh")

      delimited.gets_to_end.should eq("abab1234")
    end

    it "handles partial reads" do
      io = PartialReaderIO.new("abab1234abcdefgh")
      delimited = IO::Delimited.new(io, read_delimiter: "abcdefgh")

      delimited.gets_to_end.should eq("abab1234")
    end
  end

  describe "#write" do
    it "raises" do
      delimited = IO::Delimited.new(IO::Memory.new, read_delimiter: "zr")
      expect_raises(IO::Error, "Can't write to IO::Delimited") do
        delimited.puts "test string"
      end
    end
  end

  describe "#close" do
    it "stops reading" do
      io = IO::Memory.new "abcdefg"
      delimited = IO::Delimited.new(io, read_delimiter: "zr")

      delimited.read_char.should eq('a')
      delimited.read_char.should eq('b')

      delimited.close
      delimited.closed?.should eq(true)
      expect_raises(IO::Error, "Closed stream") do
        delimited.read_char
      end
    end

    it "closes the underlying stream if sync_close is true" do
      io = IO::Memory.new "abcdefg"
      delimited = IO::Delimited.new(io, read_delimiter: "zr", sync_close: true)
      delimited.sync_close?.should eq(true)

      io.closed?.should eq(false)
      delimited.close
      io.closed?.should eq(true)
    end
  end
end
