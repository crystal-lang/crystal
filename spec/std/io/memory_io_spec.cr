require "spec"

describe "MemoryIO" do
  it "writes" do
    io = MemoryIO.new
    io.bytesize.should eq(0)
    io.write Slice.new("hello".to_unsafe, 3)
    io.bytesize.should eq(3)
    io.rewind
    io.gets_to_end.should eq("hel")
  end

  it "writes big" do
    s = "hi" * 100
    io = MemoryIO.new
    io.write Slice.new(s.to_unsafe, s.bytesize)
    io.rewind
    io.gets_to_end.should eq(s)
  end

  it "reads byte" do
    io = MemoryIO.new("abc")
    io.read_byte.should eq('a'.ord)
    io.read_byte.should eq('b'.ord)
    io.read_byte.should eq('c'.ord)
    io.read_byte.should be_nil
  end

  it "appends to another buffer" do
    s1 = MemoryIO.new
    s1 << "hello"

    s2 = MemoryIO.new
    s1.to_s(s2)
    s2.to_s.should eq("hello")
  end

  it "reads single line content" do
    io = MemoryIO.new("foo")
    io.gets.should eq("foo")
  end

  it "reads each line" do
    io = MemoryIO.new("foo\r\nbar\r\n")
    io.gets.should eq("foo\r\n")
    io.gets.should eq("bar\r\n")
    io.gets.should eq(nil)
  end

  it "gets with char as delimiter" do
    io = MemoryIO.new("hello world")
    io.gets('w').should eq("hello w")
    io.gets('r').should eq("or")
    io.gets('r').should eq("ld")
    io.gets('r').should eq(nil)
  end

  it "does gets with char and limit" do
    io = MemoryIO.new("hello\nworld\n")
    io.gets('o', 2).should eq("he")
    io.gets('w', 10_000).should eq("llo\nw")
    io.gets('z', 10_000).should eq("orld\n")
    io.gets('a', 3).should be_nil
  end

  it "does gets with limit" do
    io = MemoryIO.new("hello\nworld")
    io.gets(3).should eq("hel")
    io.gets(3).should eq("lo\n")
    io.gets(3).should eq("wor")
    io.gets(3).should eq("ld")
    io.gets(3).should be_nil
  end

  it "raises if invoking gets with negative limit" do
    io = MemoryIO.new("hello\nworld\n")
    expect_raises ArgumentError, "negative limit" do
      io.gets(-1)
    end
  end

  it "write single byte" do
    io = MemoryIO.new
    io.write_byte 97_u8
    io.to_s.should eq("a")
  end

  it "writes and reads" do
    io = MemoryIO.new
    io << "foo" << "bar"
    io.rewind
    io.gets.should eq("foobar")
  end

  it "can be converted to slice" do
    str = MemoryIO.new
    str.write_byte 0_u8
    str.write_byte 1_u8
    slice = str.to_slice
    slice.size.should eq(2)
    slice[0].should eq(0_u8)
    slice[1].should eq(1_u8)
  end

  it "reads more than available (#1229)" do
    s = "h" * (10 * 1024)
    str = MemoryIO.new(s)
    str.gets(11 * 1024).should eq(s)
  end

  it "writes after reading" do
    io = MemoryIO.new
    io << "abcdefghi"
    io.rewind
    io.gets(3)
    io.print("xyz")
    io.rewind
    io.gets_to_end.should eq("abcxyzghi")
  end

  it "has a size" do
    MemoryIO.new("foo").size.should eq(3)
  end

  it "can tell" do
    io = MemoryIO.new("foo")
    io.tell.should eq(0)
    io.gets(2)
    io.tell.should eq(2)
  end

  it "can seek set" do
    io = MemoryIO.new("abcdef")
    io.seek(3)
    io.tell.should eq(3)
    io.gets(1).should eq("d")
  end

  it "raises if seek set is negative" do
    io = MemoryIO.new("abcdef")
    expect_raises(ArgumentError, "negative pos") do
      io.seek(-1)
    end
  end

  it "can seek past the end" do
    io = MemoryIO.new
    io << "abc"
    io.rewind
    io.seek(6)
    io.gets_to_end.should eq("")
    io.print("xyz")
    io.rewind
    io.gets_to_end.should eq("abc\u{0}\u{0}\u{0}xyz")
  end

  it "can seek current" do
    io = MemoryIO.new("abcdef")
    io.seek(2)
    io.seek(1, IO::Seek::Current)
    io.gets(1).should eq("d")
  end

  it "raises if seek current leads to negative value" do
    io = MemoryIO.new("abcdef")
    io.seek(2)
    expect_raises(ArgumentError, "negative pos") do
      io.seek(-3, IO::Seek::Current)
    end
  end

  it "can seek from the end" do
    io = MemoryIO.new("abcdef")
    io.seek(-2, IO::Seek::End)
    io.gets(1).should eq("e")
  end

  it "can be closed" do
    io = MemoryIO.new
    io << "abc"
    io.close
    io.closed?.should be_true

    expect_raises(IO::Error, "closed stream") { io.gets_to_end }
    expect_raises(IO::Error, "closed stream") { io.print "hi" }
    expect_raises(IO::Error, "closed stream") { io.seek(1) }
    expect_raises(IO::Error, "closed stream") { io.gets }
    expect_raises(IO::Error, "closed stream") { io.read_byte }
  end

  it "seeks with pos and pos=" do
    io = MemoryIO.new("abcdef")
    io.pos = 4
    io.gets(1).should eq("e")
    io.pos -= 2
    io.gets(1).should eq("d")
  end

  it "clears" do
    io = MemoryIO.new
    io << "abc"
    io.rewind
    io.gets(1)
    io.clear
    io.pos.should eq(0)
    io.gets_to_end.should eq("")
  end

  it "raises if negative capacity" do
    expect_raises(ArgumentError, "negative capacity") do
      MemoryIO.new(-1)
    end
  end

  it "raises if capacity too big" do
    expect_raises(ArgumentError, "capacity too big") do
      MemoryIO.new(UInt32::MAX)
    end
  end

  it "creates from string" do
    io = MemoryIO.new "abcdef"
    io.gets(2).should eq("ab")
    io.gets(3).should eq("cde")

    expect_raises(IO::Error, "read-only stream") do
      io.print 1
    end
  end

  it "creates from slice" do
    slice = Slice.new(6) { |i| ('a'.ord + i).to_u8 }
    io = MemoryIO.new slice
    io.gets(2).should eq("ab")
    io.gets(3).should eq("cde")
    io.print 'x'

    String.new(slice).should eq("abcdex")

    expect_raises(IO::Error, "non-resizeable stream") do
      io.print 'z'
    end
  end

  it "creates from slice, non-writeable" do
    slice = Slice.new(6) { |i| ('a'.ord + i).to_u8 }
    io = MemoryIO.new slice, writeable: false

    expect_raises(IO::Error, "read-only stream") do
      io.print 'z'
    end
  end

  it "writes past end" do
    io = MemoryIO.new
    io.pos = 1000
    io.print 'a'
    io.to_slice.to_a.should eq([0] * 1000 + [97])
  end

  it "writes past end with write_byte" do
    io = MemoryIO.new
    io.pos = 1000
    io.write_byte 'a'.ord.to_u8
    io.to_slice.to_a.should eq([0] * 1000 + [97])
  end

  describe "encoding" do
    describe "decode" do
      it "gets_to_end" do
        str = "Hello world" * 200
        io = MemoryIO.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets_to_end.should eq(str)
      end

      it "gets" do
        str = "Hello world\nFoo\nBar\n" + ("1234567890" * 1000)
        io = MemoryIO.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets.should eq("Hello world\n")
        io.gets.should eq("Foo\n")
        io.gets.should eq("Bar\n")
      end

      it "reads char" do
        str = "x\nHello world" + ("1234567890" * 1000)
        io = MemoryIO.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets.should eq("x\n")
        str = str[2..-1]
        str.each_char do |char|
          io.read_char.should eq(char)
        end
        io.read_char.should be_nil
      end
    end
  end
end
