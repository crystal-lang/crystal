require "spec"

private class NoPeekIO
  include IO

  def read(bytes : Bytes)
    0
  end

  def write(bytes : Bytes)
    0
  end

  def peek
    raise "shouldn't be invoked"
  end
end

describe "IO::Sized" do
  describe "#read" do
    it "doesn't read past the limit when reading char-by-char" do
      io = IO::Memory.new "abcdefg"
      sized = IO::Sized.new(io, read_size: 5)

      sized.read_char.should eq('a')
      sized.read_char.should eq('b')
      sized.read_char.should eq('c')
      sized.read_remaining.should eq(2)
      sized.read_char.should eq('d')
      sized.read_char.should eq('e')
      sized.read_remaining.should eq(0)
      sized.read_char.should be_nil
      sized.read_remaining.should eq(0)
      sized.read_char.should be_nil
    end

    it "doesn't read past the limit when reading the correct size" do
      io = IO::Memory.new("1234567")
      sized = IO::Sized.new(io, read_size: 5)
      slice = Bytes.new(5)

      sized.read(slice).should eq(5)
      String.new(slice).should eq("12345")

      sized.read(slice).should eq(0)
      String.new(slice).should eq("12345")
    end

    it "reads partially when supplied with a larger slice" do
      io = IO::Memory.new("1234567")
      sized = IO::Sized.new(io, read_size: 5)
      slice = Bytes.new(10)

      sized.read(slice).should eq(5)
      String.new(slice).should eq("12345\0\0\0\0\0")
    end

    it "raises on negative numbers" do
      io = IO::Memory.new
      expect_raises(ArgumentError, "Negative read_size") do
        IO::Sized.new(io, read_size: -1)
      end
    end
  end

  describe "#write" do
    it "raises" do
      sized = IO::Sized.new(IO::Memory.new, read_size: 5)
      expect_raises(IO::Error, "Can't write to IO::Sized") do
        sized.puts "test string"
      end
    end
  end

  describe "#close" do
    it "stops reading" do
      io = IO::Memory.new "abcdefg"
      sized = IO::Sized.new(io, read_size: 5)

      sized.read_char.should eq('a')
      sized.read_char.should eq('b')

      sized.close
      sized.closed?.should eq(true)
      expect_raises(IO::Error, "Closed stream") do
        sized.read_char
      end
    end

    it "closes the underlying stream if sync_close is true" do
      io = IO::Memory.new "abcdefg"
      sized = IO::Sized.new(io, read_size: 5, sync_close: true)
      sized.sync_close?.should eq(true)

      io.closed?.should eq(false)
      sized.close
      io.closed?.should eq(true)
    end
  end

  it "read_byte" do
    io = IO::Memory.new "abcdefg"
    sized = IO::Sized.new(io, read_size: 3)
    sized.read_byte.should eq('a'.ord)
    sized.read_byte.should eq('b'.ord)
    sized.read_byte.should eq('c'.ord)
    sized.read_byte.should be_nil
  end

  it "gets" do
    io = IO::Memory.new "foo\nbar\nbaz"
    sized = IO::Sized.new(io, read_size: 9)
    sized.gets.should eq("foo")
    sized.gets.should eq("bar")
    sized.gets.should eq("b")
    sized.gets.should be_nil
  end

  it "gets with chomp = false" do
    io = IO::Memory.new "foo\nbar\nbaz"
    sized = IO::Sized.new(io, read_size: 9)
    sized.gets(chomp: false).should eq("foo\n")
    sized.gets(chomp: false).should eq("bar\n")
    sized.gets(chomp: false).should eq("b")
    sized.gets(chomp: false).should be_nil
  end

  it "peeks" do
    io = IO::Memory.new "123456789"
    sized = IO::Sized.new(io, read_size: 6)
    sized.peek.should eq("123456".to_slice)
    sized.gets_to_end.should eq("123456")
    sized.peek.should eq(Bytes.empty)
  end

  it "doesn't peek when remaining = 0 (#4261)" do
    sized = IO::Sized.new(NoPeekIO.new, read_size: 0)
    sized.peek.should eq(Bytes.empty)
  end

  it "skips" do
    io = IO::Memory.new "123456789"
    sized = IO::Sized.new(io, read_size: 6)
    sized.skip(3)
    sized.read_char.should eq('4')

    expect_raises(IO::EOFError) do
      sized.skip(6)
    end
  end
end
