require "spec"

describe "StringIO" do
  it "writes" do
    io = StringIO.new
    io.write Slice.new("hello".cstr, 3)
    io.read.should eq("hel")
  end

  it "writes big" do
    s = "hi" * 100
    io = StringIO.new
    io.write Slice.new(s.cstr, s.bytesize)
    io.read.should eq(s)
  end

  it "appends to another buffer" do
    s1 = StringIO.new
    s1 << "hello"

    s2 = StringIO.new
    s1.to_s(s2)
    s2.to_s.should eq("hello")
  end

  it "reads single line content" do
    io = StringIO.new("foo")
    io.gets.should eq("foo")
  end

  it "reads each line" do
    io = StringIO.new("foo\r\nbar\r\n")
    io.gets.should eq("foo\r\n")
    io.gets.should eq("bar\r\n")
    io.gets.should eq(nil)
  end

  it "gets with char as delimiter" do
    io = StringIO.new("hello world")
    io.gets('w').should eq("hello w")
    io.gets('r').should eq("or")
    io.gets('r').should eq("ld")
    io.gets('r').should eq(nil)
  end

  it "does gets with char and limit" do
    io = StringIO.new("hello\nworld\n")
    io.gets('o', 2).should eq("he")
    io.gets('w', 10_000).should eq("llo\nw")
    io.gets('z', 10_000).should eq("orld\n")
    io.gets('a', 3).should be_nil
  end

  it "raises if invoking gets with negative limit" do
    io = StringIO.new("hello\nworld\n")
    expect_raises ArgumentError, "negative limit" do
      io.gets(-1)
    end
  end

  it "raises argument error if reads negative length" do
    io = StringIO.new("hello world")
    expect_raises(ArgumentError, "negative length") do
      io.read(-1)
    end
  end

  it "write single byte" do
    io = StringIO.new
    io.write_byte 97_u8
    io.to_s.should eq("a")
  end

  it "writes and reads" do
    io = StringIO.new
    io << "foo" << "bar"
    io.gets.should eq("foobar")
  end

  it "can be converted to slice" do
    str = StringIO.new
    str.write_byte 0_u8
    str.write_byte 1_u8
    slice = str.to_slice
    slice.length.should eq(2)
    slice[0].should eq(0_u8)
    slice[1].should eq(1_u8)
  end
end
