require "spec"

describe "SliceIO" do
  it "writes" do
    io = SliceIO.new(3)
    io.write Slice.new("hello".cstr, 3)
    io.rewind
    io.gets_to_end.should eq("hel")
  end

  it "writes big" do
    s = "hi" * 100
    io = SliceIO.new(s.bytesize)
    io.write Slice.new(s.cstr, s.bytesize)
    io.rewind
    io.gets_to_end.should eq(s)
  end

  it "reads byte" do
    io = SliceIO.new("abc".to_slice)
    io.read_byte.should eq('a'.ord)
    io.read_byte.should eq('b'.ord)
    io.read_byte.should eq('c'.ord)
    io.read_byte.should be_nil
  end

  it "reads single line content" do
    io = SliceIO.new("foo".to_slice)
    io.gets.should eq("foo")
  end

  it "reads each line" do
    io = SliceIO.new("foo\r\nbar\r\n".to_slice)
    io.gets.should eq("foo\r\n")
    io.gets.should eq("bar\r\n")
    io.gets.should eq(nil)
  end

  it "gets with char as delimiter" do
    io = SliceIO.new("hello world".to_slice)
    io.gets('w').should eq("hello w")
    io.gets('r').should eq("or")
    io.gets('r').should eq("ld")
    io.gets('r').should eq(nil)
  end

  it "does gets with char and limit" do
    io = SliceIO.new("hello\nworld\n".to_slice)
    io.gets('o', 2).should eq("he")
    io.gets('w', 10_000).should eq("llo\nw")
    io.gets('z', 10_000).should eq("orld\n")
    io.gets('a', 3).should be_nil
  end

  it "does gets with limit" do
    io = SliceIO.new("hello\nworld".to_slice)
    io.gets(3).should eq("hel")
    io.gets(3).should eq("lo\n")
    io.gets(3).should eq("wor")
    io.gets(3).should eq("ld")
    io.gets(3).should be_nil
  end

  it "raises if invoking gets with negative limit" do
    io = SliceIO.new("hello\nworld\n".to_slice)
    expect_raises ArgumentError, "negative limit" do
      io.gets(-1)
    end
  end

  it "write single byte" do
    io = SliceIO.new(1)
    io.write_byte 97_u8
    io.rewind
    io.gets.should eq("a")
  end

  it "writes and reads (fails)" do
    io = SliceIO.new(6)
    io << "foo" << "bar" # fails
    #io.write("foo".to_slice) # works
    #io << "bar"
    io.rewind
    io.gets.should eq("foobar")
  end

  it "can be converted to slice" do
    str = SliceIO.new(2)
    str.write_byte 0_u8
    str.write_byte 1_u8
    slice = str.to_slice
    slice.size.should eq(2)
    slice[0].should eq(0_u8)
    slice[1].should eq(1_u8)
  end

  it "reads more than available (#1229)" do
    s = "h" * (10 * 1024)
    str = SliceIO.new(s.to_slice)
    str.gets(11 * 1024).should eq(s)
  end

  it "writes after reading" do
    io = SliceIO.new("abcdefghi".to_slice)
    io.gets(3)
    io << "xyz" # fails with segfault
    io.rewind
    io.gets.should eq("abcxyzghi")
  end

  it "has a size" do
    SliceIO.new("foo".to_slice).size.should eq(3)
  end

  it "can seek set" do
    io = SliceIO.new("abcdef".to_slice)
    io.seek(3)
    io.tell.should eq(3)
    io.gets(1).should eq("d")
  end

  it "raises if seek set is negative" do
    io = SliceIO.new("abcdef".to_slice)
    expect_raises(ArgumentError, "negative pos") do
      io.seek(-1)
    end
  end

  it "raises if seek set greater than size" do
    io = SliceIO.new("abcdef".to_slice)
    expect_raises(ArgumentError, "pos out of bounds") do
      io.seek(10)
    end
  end

  it "can seek current" do
    io = SliceIO.new("abcdef".to_slice)
    io.seek(2)
    io.seek(1, IO::Seek::Current)
    io.gets(1).should eq("d")
  end

  it "raises if seek current leads to negative value" do
    io = SliceIO.new("abcdef".to_slice)
    io.seek(2)
    expect_raises(ArgumentError, "negative pos") do
      io.seek(-3, IO::Seek::Current)
    end
  end

  it "can seek from the end" do
    io = SliceIO.new("abcdef".to_slice)
    io.seek(-2, IO::Seek::End)
    io.gets(1).should eq("e")
  end
end
