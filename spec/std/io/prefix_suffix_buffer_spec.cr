require "../spec_helper"
require "io/prefix_suffix_buffer"

describe IO::PrefixSuffixBuffer do
  describe ".new(Int)" do
    it "allocates buffer" do
      IO::PrefixSuffixBuffer.new(12).capacity.should eq(24)
    end

    it "raises if negative capacity" do
      expect_raises(ArgumentError, "Negative capacity") do
        IO::PrefixSuffixBuffer.new(-1)
      end
    end
  end

  describe ".new(Bytes, Bytes)" do
    it "receives buffers" do
      IO::PrefixSuffixBuffer.new(Bytes.new(5), Bytes.new(7)).capacity.should eq(12)
    end
  end

  it "#total_size" do
    (IO::PrefixSuffixBuffer.new(32) << "foo").total_size.should eq(3)
  end

  describe "#write" do
    it "writes" do
      io = IO::PrefixSuffixBuffer.new(32)
      io.total_size.should eq(0)
      io.write Slice.new("hello".to_unsafe, 3)
      io.total_size.should eq(3)
      io.to_s.should eq("hel")
    end

    it "writes to capacity" do
      s = "hi" * 100
      io = IO::PrefixSuffixBuffer.new(100)
      io.write Slice.new(s.to_unsafe, s.bytesize)
      io.to_s.should eq(s)
    end

    it "writes single byte" do
      io = IO::PrefixSuffixBuffer.new(32)
      io.write_byte 97_u8
      io.to_s.should eq("a")
    end

    it "writes multiple times" do
      io = IO::PrefixSuffixBuffer.new(32)
      io << "foo" << "bar"
      io.to_s.should eq("foobar")
    end

    it "supports an empty prefix buffer" do
      io = IO::PrefixSuffixBuffer.new(Bytes.empty, Bytes.new(3))
      io << "abcdef"
      io.to_s.should eq("\n...omitted 3 bytes...\ndef")
    end

    it "supports an empty suffix buffer" do
      io = IO::PrefixSuffixBuffer.new(Bytes.new(3), Bytes.empty)
      io << "abcdef"
      io.to_s.should eq("abc\n...omitted 3 bytes...\n")
    end
  end

  describe "#to_s" do
    it "appends to another buffer" do
      s1 = IO::PrefixSuffixBuffer.new(32)
      s1 << "hello"

      s2 = IO::PrefixSuffixBuffer.new(32)
      s1.to_s(s2)
      s2.to_s.should eq("hello")
    end

    it "appends to itself" do
      io = IO::PrefixSuffixBuffer.new(33)
      io << "-" * 33
      io.to_s(io)
      io.to_s.should eq "-" * 66
    end

    describe "truncation" do
      it "basic" do
        io = IO::PrefixSuffixBuffer.new(5)
        io << "abcdefghijklmnopqrstuvwxyz"
        io.to_s.should eq("abcde\n...omitted 16 bytes...\nvwxyz")
      end

      it "chunked" do
        buffer = IO::PrefixSuffixBuffer.new(4)
        buffer << "---" << "-X-" << "---"
        buffer.to_s.should eq "----\n...omitted 1 bytes...\n----"
      end

      it "one" do
        io = IO::PrefixSuffixBuffer.new(1)
        io << "abc"
        io.to_s.should eq("a\n...omitted 1 bytes...\nc")
      end

      it "longer" do
        io = IO::PrefixSuffixBuffer.new(10)
        io << "abcdefghijklmnopqrstuvwxyz"
        io.to_s.should eq("abcdefghij\n...omitted 6 bytes...\nqrstuvwxyz")
      end

      it "chars" do
        io = IO::PrefixSuffixBuffer.new(10)
        "abcdefghijklmnopqrstuvwxyz".each_char do |char|
          io << char
        end
        io.to_s.should eq("abcdefghij\n...omitted 6 bytes...\nqrstuvwxyz")
      end
    end
  end
end
