require "spec"
require "big_int"
require "base64"

# This is a non-optimized version of IO::Memory so we can test
# raw IO. Optimizations for specific IOs are tested separately
# (for example in buffered_io_spec)
private class SimpleIOMemory
  include IO

  getter buffer : UInt8*
  getter bytesize : Int32
  @capacity : Int32
  @pos : Int32
  @max_read : Int32?

  def initialize(capacity = 64, @max_read = nil)
    @buffer = GC.malloc_atomic(capacity.to_u32).as(UInt8*)
    @bytesize = 0
    @capacity = capacity
    @pos = 0
  end

  def self.new(string : String, max_read = nil)
    io = new(string.bytesize, max_read: max_read)
    io << string
    io
  end

  def self.new(bytes : Bytes, max_read = nil)
    io = new(bytes.size, max_read: max_read)
    io.write(bytes)
    io
  end

  def read(slice : Bytes)
    count = slice.size
    count = Math.min(count, @bytesize - @pos)
    if max_read = @max_read
      count = Math.min(count, max_read)
    end
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  def write(slice : Bytes)
    count = slice.size
    new_bytesize = bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + @bytesize, count)
    @bytesize += count

    nil
  end

  def to_slice
    Slice.new(@buffer, @bytesize)
  end

  def to_s
    String.new @buffer, @bytesize
  end

  def rewind
    @pos = 0
    self
  end

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if @bytesize == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end

describe IO do
  describe "partial read" do
    it "doesn't block on first read.  blocks on 2nd read" do
      IO.pipe do |read, write|
        write.puts "hello"
        slice = Bytes.new 1024

        read.read_timeout = 1
        read.read(slice).should eq(6)

        expect_raises(IO::Timeout) do
          read.read_timeout = 0.0000001
          read.read(slice)
        end
      end
    end
  end

  describe "IO iterators" do
    it "iterates by line" do
      io = SimpleIOMemory.new("hello\nbye\n")
      lines = io.each_line
      lines.next.should eq("hello")
      lines.next.should eq("bye")
      lines.next.should be_a(Iterator::Stop)

      lines.rewind
      lines.next.should eq("hello")
    end

    it "iterates by line with chomp false" do
      io = SimpleIOMemory.new("hello\nbye\n")
      lines = io.each_line(chomp: false)
      lines.next.should eq("hello\n")
      lines.next.should eq("bye\n")
      lines.next.should be_a(Iterator::Stop)

      lines.rewind
      lines.next.should eq("hello\n")
    end

    it "iterates by char" do
      io = SimpleIOMemory.new("abあぼ")
      chars = io.each_char
      chars.next.should eq('a')
      chars.next.should eq('b')
      chars.next.should eq('あ')
      chars.next.should eq('ぼ')
      chars.next.should be_a(Iterator::Stop)

      chars.rewind
      chars.next.should eq('a')
    end

    it "iterates by byte" do
      io = SimpleIOMemory.new("ab")
      bytes = io.each_byte
      bytes.next.should eq('a'.ord)
      bytes.next.should eq('b'.ord)
      bytes.next.should be_a(Iterator::Stop)

      bytes.rewind
      bytes.next.should eq('a'.ord)
    end
  end

  it "copies" do
    string = "abあぼ"
    src = SimpleIOMemory.new(string)
    dst = SimpleIOMemory.new
    IO.copy(src, dst).should eq(string.bytesize)
    dst.to_s.should eq(string)
  end

  it "copies with limit" do
    string = "abcあぼ"
    src = SimpleIOMemory.new(string)
    dst = SimpleIOMemory.new
    IO.copy(src, dst, 3).should eq(3)
    dst.to_s.should eq("abc")
  end

  it "raises on copy with negative limit" do
    string = "abcあぼ"
    src = SimpleIOMemory.new(string)
    dst = SimpleIOMemory.new
    expect_raises(ArgumentError, "Negative limit") do
      IO.copy(src, dst, -10)
    end
  end

  it "reopens" do
    File.open("#{__DIR__}/../data/test_file.txt") do |file1|
      File.open("#{__DIR__}/../data/test_file.ini") do |file2|
        file2.reopen(file1)
        file2.gets.should eq("Hello World")
      end
    end
  end

  describe "read operations" do
    it "does gets" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.gets.should eq("hello")
      io.gets.should eq("world")
      io.gets.should be_nil
    end

    it "does gets with \\r\\n" do
      io = SimpleIOMemory.new("hello\r\nworld\r\nfoo\rbar\n")
      io.gets.should eq("hello")
      io.gets.should eq("world")
      io.gets.should eq("foo\rbar")
      io.gets.should be_nil
    end

    it "does gets with chomp false" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.gets(chomp: false).should eq("hello\n")
      io.gets(chomp: false).should eq("world\n")
      io.gets(chomp: false).should be_nil
    end

    it "does gets with big line" do
      big_line = "a" * 20_000
      io = SimpleIOMemory.new("#{big_line}\nworld\n")
      io.gets.should eq(big_line)
    end

    it "does gets with char delimiter" do
      io = SimpleIOMemory.new("hello world")
      io.gets('w').should eq("hello w")
      io.gets('r').should eq("or")
      io.gets('r').should eq("ld")
      io.gets('r').should be_nil
    end

    it "does gets with unicode char delimiter" do
      io = SimpleIOMemory.new("こんにちは")
      io.gets('ち').should eq("こんにち")
      io.gets('ち').should eq("は")
      io.gets('ち').should be_nil
    end

    it "gets with string as delimiter" do
      io = SimpleIOMemory.new("hello world")
      io.gets("lo").should eq("hello")
      io.gets("rl").should eq(" worl")
      io.gets("foo").should eq("d")
    end

    it "gets with string as delimiter and chomp = true" do
      io = SimpleIOMemory.new("hello world")
      io.gets("lo", chomp: true).should eq("hel")
      io.gets("rl", chomp: true).should eq(" wo")
      io.gets("foo", chomp: true).should eq("d")
    end

    it "gets with empty string as delimiter" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.gets("").should eq("hello\nworld\n")
    end

    it "gets with single byte string as delimiter" do
      io = SimpleIOMemory.new("hello\nworld\nbye")
      io.gets("\n").should eq("hello\n")
      io.gets("\n").should eq("world\n")
      io.gets("\n").should eq("bye")
    end

    it "does gets with limit" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.gets(3).should eq("hel")
      io.gets(10_000).should eq("lo\n")
      io.gets(10_000).should eq("world\n")
      io.gets(3).should be_nil
    end

    it "does gets with char and limit" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.gets('o', 2).should eq("he")
      io.gets('w', 10_000).should eq("llo\nw")
      io.gets('z', 10_000).should eq("orld\n")
      io.gets('a', 3).should be_nil
    end

    it "raises if invoking gets with negative limit" do
      io = SimpleIOMemory.new("hello\nworld\n")
      expect_raises ArgumentError, "Negative limit" do
        io.gets(-1)
      end
    end

    it "does read_line with limit" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.read_line(3).should eq("hel")
      io.read_line(10_000).should eq("lo\n")
      io.read_line(10_000).should eq("world\n")
      expect_raises(IO::EOFError) { io.read_line(3) }
    end

    it "does read_line with char and limit" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.read_line('o', 2).should eq("he")
      io.read_line('w', 10_000).should eq("llo\nw")
      io.read_line('z', 10_000).should eq("orld\n")
      expect_raises(IO::EOFError) { io.read_line('a', 3) }
    end

    it "reads all remaining content" do
      io = SimpleIOMemory.new("foo\nbar\nbaz\n")
      io.gets.should eq("foo")
      io.gets_to_end.should eq("bar\nbaz\n")
    end

    it "reads char" do
      io = SimpleIOMemory.new("hi 世界")
      io.read_char.should eq('h')
      io.read_char.should eq('i')
      io.read_char.should eq(' ')
      io.read_char.should eq('世')
      io.read_char.should eq('界')
      io.read_char.should be_nil

      io.write Bytes[0xf8, 0xff, 0xff, 0xff]
      expect_raises(InvalidByteSequenceError) do
        io.read_char
      end

      io.write_byte 0x81_u8
      expect_raises(InvalidByteSequenceError) do
        io.read_char
      end
    end

    it "reads byte" do
      io = SimpleIOMemory.new("hello")
      io.read_byte.should eq('h'.ord)
      io.read_byte.should eq('e'.ord)
      io.read_byte.should eq('l'.ord)
      io.read_byte.should eq('l'.ord)
      io.read_byte.should eq('o'.ord)
      io.read_char.should be_nil
    end

    it "reads string" do
      io = SimpleIOMemory.new("hello world")
      io.read_string(5).should eq("hello")
      io.read_string(1).should eq(" ")
      io.read_string(0).should eq("")
      expect_raises(IO::EOFError) do
        io.read_string(6)
      end
    end

    it "does each_line" do
      io = SimpleIOMemory.new("a\nbb\ncc")
      counter = 0
      io.each_line do |line|
        case counter
        when 0
          line.should eq("a")
        when 1
          line.should eq("bb")
        when 2
          line.should eq("cc")
        end
        counter += 1
      end.should be_nil
      counter.should eq(3)
    end

    it "does each_char" do
      io = SimpleIOMemory.new("あいう")
      counter = 0
      io.each_char do |c|
        case counter
        when 0
          c.should eq('あ')
        when 1
          c.should eq('い')
        when 2
          c.should eq('う')
        end
        counter += 1
      end.should be_nil
      counter.should eq(3)
    end

    it "does each_byte" do
      io = SimpleIOMemory.new("abc")
      counter = 0
      io.each_byte do |b|
        case counter
        when 0
          b.should eq('a'.ord)
        when 1
          b.should eq('b'.ord)
        when 2
          b.should eq('c'.ord)
        end
        counter += 1
      end.should be_nil
      counter.should eq(3)
    end

    it "raises on EOF with read_line" do
      str = SimpleIOMemory.new("hello")
      str.read_line.should eq("hello")

      expect_raises IO::EOFError, "End of file reached" do
        str.read_line
      end
    end

    it "raises on EOF with readline and delimiter" do
      str = SimpleIOMemory.new("hello")
      str.read_line('e').should eq("he")
      str.read_line('e').should eq("llo")

      expect_raises IO::EOFError, "End of file reached" do
        str.read_line
      end
    end

    it "does read_fully" do
      str = SimpleIOMemory.new("hello")
      slice = Bytes.new(4)
      str.read_fully(slice).should eq(4)
      String.new(slice).should eq("hell")

      expect_raises(IO::EOFError) do
        str.read_fully(slice)
      end
    end

    it "does read_fully?" do
      str = SimpleIOMemory.new("hello")
      slice = Bytes.new(4)
      str.read_fully?(slice).should eq(4)
      String.new(slice).should eq("hell")

      str.read_fully?(slice).should be_nil
    end
  end

  describe "write operations" do
    it "does puts" do
      io = SimpleIOMemory.new
      io.puts "Hello"
      io.gets_to_end.should eq("Hello\n")
    end

    it "does puts with big string" do
      io = SimpleIOMemory.new
      s = "*" * 20_000
      io << "hello"
      io << s
      io.gets_to_end.should eq("hello#{s}")
    end

    it "does puts many times" do
      io = SimpleIOMemory.new
      10_000.times { io << "hello" }
      io.gets_to_end.should eq("hello" * 10_000)
    end

    it "puts several arguments" do
      io = SimpleIOMemory.new
      io.puts(1, "aaa", "\n")
      io.gets_to_end.should eq("1\naaa\n\n")
    end

    it "prints" do
      io = SimpleIOMemory.new
      io.print "foo"
      io.gets_to_end.should eq("foo")
    end

    it "prints several arguments" do
      io = SimpleIOMemory.new
      io.print "foo", "bar", "baz"
      io.gets_to_end.should eq("foobarbaz")
    end

    it "writes bytes" do
      io = SimpleIOMemory.new
      10_000.times { io.write_byte 'a'.ord.to_u8 }
      io.gets_to_end.should eq("a" * 10_000)
    end

    it "writes with printf" do
      io = SimpleIOMemory.new
      io.printf "Hello %d", 123
      io.gets_to_end.should eq("Hello 123")
    end

    it "writes with printf as an array" do
      io = SimpleIOMemory.new
      io.printf "Hello %d", [123]
      io.gets_to_end.should eq("Hello 123")
    end

    it "skips a few bytes" do
      io = SimpleIOMemory.new
      io << "hello world"
      io.skip(6)
      io.gets_to_end.should eq("world")
    end

    it "skips but raises if not enough bytes" do
      io = SimpleIOMemory.new
      io << "hello"
      expect_raises(IO::EOFError) do
        io.skip(6)
      end
    end

    it "skips more than 4096 bytes" do
      io = SimpleIOMemory.new
      io << "a" * 4100
      io.skip(4099)
      io.gets_to_end.should eq("a")
    end

    it "skips to end" do
      io = SimpleIOMemory.new
      io << "hello"
      io.skip_to_end
      io.read_byte.should be_nil
    end
  end

  describe "encoding" do
    describe "decode" do
      it "gets_to_end" do
        str = "Hello world" * 200
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets_to_end.should eq(str)
      end

      it "gets" do
        str = "Hello world\r\nFoo\nBar"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets.should eq("Hello world")
        io.gets.should eq("Foo")
        io.gets.should eq("Bar")
        io.gets.should be_nil
      end

      it "gets with chomp = false" do
        str = "Hello world\r\nFoo\nBar"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets(chomp: false).should eq("Hello world\r\n")
        io.gets(chomp: false).should eq("Foo\n")
        io.gets(chomp: false).should eq("Bar")
        io.gets(chomp: false).should be_nil
      end

      it "gets big string" do
        str = "Hello\nWorld\n" * 10_000
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        10_000.times do |i|
          io.gets.should eq("Hello")
          io.gets.should eq("World")
        end
      end

      it "gets big GB2312 string" do
        2.times do
          str = ("你好我是人\n" * 1000).encode("GB2312")
          io = SimpleIOMemory.new(str)
          io.set_encoding("GB2312")
          1000.times do
            io.gets.should eq("你好我是人")
          end
        end
      end

      it "does gets on unicode with char and limit without off-by-one" do
        io = SimpleIOMemory.new("test\nabc".encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets('a', 5).should eq("test\n")
        io = SimpleIOMemory.new("test\nabc".encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets('a', 6).should eq("test\na")
      end

      it "gets with limit" do
        str = "Hello\nWorld\n"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets(3).should eq("Hel")
      end

      it "gets with limit (small, no newline)" do
        str = "Hello world" * 10_000
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets(3).should eq("Hel")
      end

      it "gets with non-ascii" do
        str = "你好我是人"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets('人').should eq("你好我是人")
      end

      it "gets with non-ascii and chomp: false" do
        str = "你好我是人"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets('人', chomp: true).should eq("你好我是")
      end

      it "gets with limit (big)" do
        str = "Hello world" * 10_000
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets(20_000).should eq(str[0, 20_000])
      end

      it "gets with string delimiter" do
        str = "Hello world\nFoo\nBar"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.gets("wo").should eq("Hello wo")
        io.gets("oo").should eq("rld\nFoo")
        io.gets("xx").should eq("\nBar")
        io.gets("zz").should be_nil
      end

      it "reads char" do
        str = "Hello world"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        str.each_char do |char|
          io.read_char.should eq(char)
        end
        io.read_char.should be_nil
      end

      it "reads utf8 byte" do
        str = "Hello world"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        str.each_byte do |byte|
          io.read_utf8_byte.should eq(byte)
        end
        io.read_utf8_byte.should be_nil
      end

      it "reads utf8" do
        io = IO::Memory.new("你".encode("GB2312"))
        io.set_encoding("GB2312")

        buffer = uninitialized UInt8[1024]
        bytes_read = io.read_utf8(buffer.to_slice) # => 3
        bytes_read.should eq(3)
        buffer.to_slice[0, bytes_read].to_a.should eq("你".bytes)
      end

      it "raises on incomplete byte sequence" do
        io = SimpleIOMemory.new("好".byte_slice(0, 1))
        io.set_encoding("GB2312")
        expect_raises ArgumentError, "Incomplete multibyte sequence" do
          io.read_char
        end
      end

      it "says invalid byte sequence" do
        io = SimpleIOMemory.new(Slice.new(1, 140_u8))
        io.set_encoding("GB2312")
        expect_raises ArgumentError, "Invalid multibyte sequence" do
          io.read_char
        end
      end

      it "skips invalid byte sequences" do
        string = String.build do |str|
          str.write "好".encode("GB2312")
          str.write_byte 140_u8
          str.write "是".encode("GB2312")
        end
        io = SimpleIOMemory.new(string)
        io.set_encoding("GB2312", invalid: :skip)
        io.read_char.should eq('好')
        io.read_char.should eq('是')
        io.read_char.should be_nil
      end

      it "says invalid 'invalid' option" do
        io = SimpleIOMemory.new
        expect_raises ArgumentError, "Valid values for `invalid` option are `nil` and `:skip`, not :foo" do
          io.set_encoding("GB2312", invalid: :foo)
        end
      end

      it "says invalid encoding" do
        io = SimpleIOMemory.new("foo")
        io.set_encoding("FOO")
        expect_raises ArgumentError, "Invalid encoding: FOO" do
          io.gets_to_end
        end
      end

      it "does skips when converting to UTF-8" do
        io = SimpleIOMemory.new(Base64.decode_string("ey8qx+Tl8fwg7+Dw4Ozl8vD7IOLo5+jy4CovfQ=="))
        io.set_encoding("UTF-8", invalid: :skip)
        io.gets_to_end.should eq "{/*  */}"
      end

      it "decodes incomplete multibyte sequence with skip (#3285)" do
        bytes = Bytes[195, 229, 237, 229, 240, 224, 246, 232, 255, 32, 241, 234, 240, 232, 239, 242, 224, 32, 48, 46, 48, 49, 50, 54, 32, 241, 229, 234, 243, 237, 228, 10]
        m = IO::Memory.new(bytes)
        m.set_encoding("UTF-8", invalid: :skip)
        m.gets_to_end.should eq("  0.0126 \n")
      end

      it "decodes incomplete multibyte sequence with skip (2) (#3285)" do
        str = File.read("#{__DIR__}/../data/io_data_incomplete_multibyte_sequence.txt")
        m = IO::Memory.new(Base64.decode_string str)
        m.set_encoding("UTF-8", invalid: :skip)
        m.gets_to_end.bytesize.should eq(4277)
      end

      it "decodes incomplete multibyte sequence with skip (3) (#3285)" do
        str = File.read("#{__DIR__}/../data/io_data_incomplete_multibyte_sequence_2.txt")
        m = IO::Memory.new(Base64.decode_string str)
        m.set_encoding("UTF-8", invalid: :skip)
        m.gets_to_end.bytesize.should eq(8977)
      end

      it "reads string" do
        str = "Hello world\r\nFoo\nBar"
        io = SimpleIOMemory.new(str.encode("UCS-2LE"))
        io.set_encoding("UCS-2LE")
        io.read_string(11).should eq("Hello world")
        io.gets_to_end.should eq("\r\nFoo\nBar")
      end
    end

    describe "encode" do
      it "prints a string" do
        str = "Hello world"
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.print str
        slice = io.to_slice
        slice.should eq(str.encode("UCS-2LE"))
      end

      it "prints numbers" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.print 0
        io.print 1_u8
        io.print 2_u16
        io.print 3_u32
        io.print 4_u64
        io.print 5_i8
        io.print 6_i16
        io.print 7_i32
        io.print 8_i64
        io.print 9.1_f32
        io.print 10.11_f64
        slice = io.to_slice
        slice.should eq("0123456789.110.11".encode("UCS-2LE"))
      end

      it "prints bool" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.print true
        io.print false
        slice = io.to_slice
        slice.should eq("truefalse".encode("UCS-2LE"))
      end

      it "prints char" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.print 'a'
        slice = io.to_slice
        slice.should eq("a".encode("UCS-2LE"))
      end

      it "prints symbol" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.print :foo
        slice = io.to_slice
        slice.should eq("foo".encode("UCS-2LE"))
      end

      it "prints big int" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.print 123_456.to_big_i
        slice = io.to_slice
        slice.should eq("123456".encode("UCS-2LE"))
      end

      it "puts" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.puts 1
        io.puts
        slice = io.to_slice
        slice.should eq("1\n\n".encode("UCS-2LE"))
      end

      it "printf" do
        io = SimpleIOMemory.new
        io.set_encoding("UCS-2LE")
        io.printf "%s-%d-%.2f", "hi", 123, 45.67
        slice = io.to_slice
        slice.should eq("hi-123-45.67".encode("UCS-2LE"))
      end

      it "raises on invalid byte sequence" do
        io = SimpleIOMemory.new
        io.set_encoding("GB2312")
        expect_raises ArgumentError, "Invalid multibyte sequence" do
          io.print "ñ"
        end
      end

      it "skips on invalid byte sequence" do
        io = SimpleIOMemory.new
        io.set_encoding("GB2312", invalid: :skip)
        io.print "ñ"
        io.print "foo"
      end

      it "raises on incomplete byte sequence" do
        io = SimpleIOMemory.new
        io.set_encoding("GB2312")
        expect_raises ArgumentError, "Incomplete multibyte sequence" do
          io.print "好".byte_slice(0, 1)
        end
      end

      it "says invalid encoding" do
        io = SimpleIOMemory.new
        io.set_encoding("FOO")
        expect_raises ArgumentError, "Invalid encoding: FOO" do
          io.puts "a"
        end
      end
    end

    describe "#encoding" do
      it "returns \"UTF-8\" if the encoding is not manually set" do
        SimpleIOMemory.new.encoding.should eq("UTF-8")
      end

      it "returns the name of the encoding set via #set_encoding" do
        io = SimpleIOMemory.new
        io.set_encoding("UTF-16LE")
        io.encoding.should eq("UTF-16LE")
      end
    end
  end

  typeof(STDIN.cooked { })
  typeof(STDIN.cooked!)
end
