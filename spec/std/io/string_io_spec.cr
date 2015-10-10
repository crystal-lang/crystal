require "spec"

describe "StringIO" do
  it "writes" do
    io = StringIO.new
    io.bytesize.should eq(0)
    io.write Slice.new("hello".cstr, 3)
    io.bytesize.should eq(3)
    io.rewind
    io.gets_to_end.should eq("hel")
  end

  it "writes big" do
    s = "hi" * 100
    io = StringIO.new
    io.write Slice.new(s.cstr, s.bytesize)
    io.rewind
    io.gets_to_end.should eq(s)
  end

  it "reads byte" do
    io = StringIO.new("abc")
    io.read_byte.should eq('a'.ord)
    io.read_byte.should eq('b'.ord)
    io.read_byte.should eq('c'.ord)
    io.read_byte.should be_nil
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

  it "does gets with limit" do
    io = StringIO.new("hello\nworld")
    io.gets(3).should eq("hel")
    io.gets(3).should eq("lo\n")
    io.gets(3).should eq("wor")
    io.gets(3).should eq("ld")
    io.gets(3).should be_nil
  end

  it "raises if invoking gets with negative limit" do
    io = StringIO.new("hello\nworld\n")
    expect_raises ArgumentError, "negative limit" do
      io.gets(-1)
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
    io.rewind
    io.gets.should eq("foobar")
  end

  it "can be converted to slice" do
    str = StringIO.new
    str.write_byte 0_u8
    str.write_byte 1_u8
    slice = str.to_slice
    slice.size.should eq(2)
    slice[0].should eq(0_u8)
    slice[1].should eq(1_u8)
  end

  it "reads more than available (#1229)" do
    s = "h" * (10 * 1024)
    str = StringIO.new(s)
    str.gets(11 * 1024).should eq(s)
  end

  it "writes after reading" do
    io = StringIO.new("abcdefghi")
    io.gets(3)
    io.print("xyz")
    io.rewind
    io.gets_to_end.should eq("abcxyzghi")
  end

  it "has a size" do
    StringIO.new("foo").size.should eq(3)
  end

  it "can tell" do
    io = StringIO.new("foo")
    io.tell.should eq(0)
    io.gets(2)
    io.tell.should eq(2)
  end

  it "can seek set" do
    io = StringIO.new("abcdef")
    io.seek(3)
    io.tell.should eq(3)
    io.gets(1).should eq("d")
  end

  it "raises if seek set is negative" do
    io = StringIO.new("abcdef")
    expect_raises(ArgumentError, "negative pos") do
      io.seek(-1)
    end
  end

  it "can seek past the end" do
    io = StringIO.new("abc")
    io.seek(6)
    io.gets_to_end.should eq("")
    io.print("xyz")
    io.rewind
    io.gets_to_end.should eq("abc\u{0}\u{0}\u{0}xyz")
  end

  it "can seek current" do
    io = StringIO.new("abcdef")
    io.seek(2)
    io.seek(1, IO::Seek::Current)
    io.gets(1).should eq("d")
  end

  it "raises if seek current leads to negative value" do
    io = StringIO.new("abcdef")
    io.seek(2)
    expect_raises(ArgumentError, "negative pos") do
      io.seek(-3, IO::Seek::Current)
    end
  end

  it "can seek from the end" do
    io = StringIO.new("abcdef")
    io.seek(-2, IO::Seek::End)
    io.gets(1).should eq("e")
  end

  it "can be closed" do
    io = StringIO.new("abc")
    io.close
    io.closed?.should be_true

    expect_raises(IO::Error, "closed stream") { io.gets_to_end }
    expect_raises(IO::Error, "closed stream") { io.print "hi" }
    expect_raises(IO::Error, "closed stream") { io.seek(1) }
    expect_raises(IO::Error, "closed stream") { io.gets }
    expect_raises(IO::Error, "closed stream") { io.read_byte }
  end

  it "seeks with pos and pos=" do
    io = StringIO.new("abcdef")
    io.pos = 4
    io.gets(1).should eq("e")
    io.pos -= 2
    io.gets(1).should eq("d")
  end

  it "clears" do
    io = StringIO.new("abc")
    io.gets(1)
    io.clear
    io.pos.should eq(0)
    io.gets_to_end.should eq("")
  end

  it "raises if negative capacity" do
    expect_raises(ArgumentError, "negative capacity") do
      StringIO.new(-1)
    end
  end

  it "raises if capacity too big" do
    expect_raises(ArgumentError, "capacity too big") do
      StringIO.new(UInt32::MAX)
    end
  end
end
