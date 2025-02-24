require "../spec_helper"
require "../../support/channel"
require "../../support/string"
require "spec/helpers/iterate"

require "socket"
require "big"
require "base64"

# This is a non-optimized version of IO::Memory so we can test
# raw IO. Optimizations for specific IOs are tested separately
# (for example in buffered_io_spec)
private class SimpleIOMemory < IO
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

  def write(slice : Bytes) : Nil
    count = slice.size
    new_bytesize = bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + @bytesize, count)
    @bytesize += count
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

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = GC.realloc(@buffer, @capacity)
  end
end

private class OneByOneIO < IO
  @bytes : Bytes

  def initialize(string)
    @bytes = string.to_slice
    @pos = 0
  end

  def read(slice : Bytes)
    return 0 if slice.empty?
    return 0 if @pos >= @bytes.size

    slice[0] = @bytes[@pos]
    @pos += 1
    1
  end

  def write(slice : Bytes) : Nil
  end
end

describe IO do
  describe "partial read" do
    it "doesn't block on first read.  blocks on 2nd read" do
      IO.pipe do |read, write|
        write.puts "hello"
        slice = Bytes.new 1024

        read.read_timeout = 1.second
        read.read(slice).should eq(6)

        expect_raises(IO::TimeoutError) do
          read.read_timeout = 0.1.microseconds
          read.read(slice)
        end
      end
    end
  end

  it_iterates "#each_line", ["hello", "bye"], SimpleIOMemory.new("hello\nbye\n").each_line
  it_iterates "#each_line(chomp: false)", ["hello\n", "bye\n"], SimpleIOMemory.new("hello\nbye\n").each_line(chomp: false)

  it_iterates "#char", ['a', 'b', 'あ', 'ぼ'], SimpleIOMemory.new("abあぼ").each_char
  it_iterates "#char", ['a'.ord.to_u8, 'b'.ord.to_u8], SimpleIOMemory.new("ab").each_byte

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

    it "does gets with \\r\\n, chomp true goes past \\r" do
      io = SimpleIOMemory.new("hello\rworld\r\nfoo\rbar\n")
      io.gets(chomp: true, limit: 8).should eq("hello\rwo")
    end

    it "does gets with chomp false" do
      io = SimpleIOMemory.new("hello\nworld\n")
      io.gets(chomp: false).should eq("hello\n")
      io.gets(chomp: false).should eq("world\n")
      io.gets(chomp: false).should be_nil
    end

    it "does gets with empty string (no peek)" do
      io = SimpleIOMemory.new("")
      io.gets(chomp: true).should be_nil
    end

    it "does gets with empty string (with peek)" do
      io = IO::Memory.new("")
      io.gets(chomp: true).should be_nil
    end

    it "does gets with \\n (no peek)" do
      io = SimpleIOMemory.new("\n")
      io.gets(chomp: true).should eq("")
      io.gets(chomp: true).should be_nil
    end

    it "does gets with \\n (with peek)" do
      io = IO::Memory.new("\n")
      io.gets(chomp: true).should eq("")
      io.gets(chomp: true).should be_nil
    end

    it "does gets with \\r\\n (no peek)" do
      io = SimpleIOMemory.new("\r\n")
      io.gets(chomp: true).should eq("")
      io.gets(chomp: true).should be_nil
    end

    it "does gets with \\r\\n (with peek)" do
      io = IO::Memory.new("\r\n")
      io.gets(chomp: true).should eq("")
      io.gets(chomp: true).should be_nil
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
      io.gets('\n').should eq("hello\n")
      io.gets('\n').should eq("world\n")
      io.gets('\n').should eq("bye")
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

    it "doesn't underflow when limit is unsigned" do
      io = IO::Memory.new("aїa")
      io.gets('є', 2u32).should eq("aї")
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
      io.gets_to_end.should eq("")
    end

    it "reads all remaining content as bytes" do
      io = SimpleIOMemory.new(Bytes[0, 1, 3, 6, 10, 15])
      io.getb_to_end.should eq(Bytes[0, 1, 3, 6, 10, 15])
      io.getb_to_end.should eq(Bytes[])
      io.rewind
      bytes = io.getb_to_end
      bytes.should eq(Bytes[0, 1, 3, 6, 10, 15])
      bytes.read_only?.should be_false

      io.rewind
      io.write(Bytes[2, 4, 5])
      bytes.should eq(Bytes[0, 1, 3, 6, 10, 15])
    end

    it "reads char" do
      io = SimpleIOMemory.new("hi 世界")
      io.read_char.should eq('h')
      io.read_char.should eq('i')
      io.read_char.should eq(' ')
      io.read_char.should eq('世')
      io.read_char.should eq('界')
      io.read_char.should be_nil

      {% for bytes, char in VALID_UTF8_BYTE_SEQUENCES %}
        SimpleIOMemory.new(Bytes{{ bytes }}).read_char.should eq({{ char }})
      {% end %}

      {% for bytes in INVALID_UTF8_BYTE_SEQUENCES %}
        expect_raises(InvalidByteSequenceError) { SimpleIOMemory.new(Bytes{{ bytes }}).read_char }
      {% end %}
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
      lines = [] of String
      io = SimpleIOMemory.new("a\nbb\ncc")
      io.each_line do |line|
        lines << line
      end
      lines.should eq ["a", "bb", "cc"]
    end

    it "does each_char" do
      chars = [] of Char
      io = SimpleIOMemory.new("あいう")
      io.each_char do |c|
        chars << c
      end
      chars.should eq ['あ', 'い', 'う']
    end

    it "does each_byte" do
      bytes = [] of UInt8
      io = SimpleIOMemory.new("abc")
      io.each_byte do |b|
        bytes << b
      end
      bytes.should eq ['a'.ord.to_u8, 'b'.ord.to_u8, 'c'.ord.to_u8]
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

    # pipe(2) returns bidirectional file descriptors on some platforms,
    # gate this test behind the platform flag.
    {% unless flag?(:freebsd) || flag?(:solaris) || flag?(:openbsd) || flag?(:dragonfly) %}
      it "raises if trying to read to an IO not opened for reading" do
        IO.pipe do |r, w|
          expect_raises(IO::Error, "File not open for reading") do
            w.gets
          end
        end
      end
    {% end %}

    describe ".same_content?" do
      it "compares two ios, one way (true)" do
        io1 = OneByOneIO.new("hello")
        io2 = IO::Memory.new("hello")
        IO.same_content?(io1, io2).should be_true
      end

      it "compares two ios, second way (true)" do
        io1 = OneByOneIO.new("hello")
        io2 = IO::Memory.new("hello")
        IO.same_content?(io2, io1).should be_true
      end

      it "compares two ios, one way (false)" do
        io1 = OneByOneIO.new("hello")
        io2 = IO::Memory.new("hella")
        IO.same_content?(io1, io2).should be_false
      end

      it "compares two ios, second way (false)" do
        io1 = OneByOneIO.new("hello")
        io2 = IO::Memory.new("hella")
        IO.same_content?(io2, io1).should be_false
      end

      it "refutes prefix match, one way" do
        io1 = OneByOneIO.new("hello")
        io2 = IO::Memory.new("hello again")
        IO.same_content?(io1, io2).should be_false
      end

      it "refutes prefix match, second way" do
        io1 = IO::Memory.new("hello")
        io2 = OneByOneIO.new("hello again")
        IO.same_content?(io1, io2).should be_false
      end

      it "refutes prefix match, one way" do
        io1 = OneByOneIO.new("hello again")
        io2 = IO::Memory.new("hello")
        IO.same_content?(io1, io2).should be_false
      end

      it "refutes prefix match, second way" do
        io1 = IO::Memory.new("hello again")
        io2 = OneByOneIO.new("hello")
        IO.same_content?(io1, io2).should be_false
      end
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

    # pipe(2) returns bidirectional file descriptors on some platforms,
    # gate this test behind the platform flag.
    {% unless flag?(:freebsd) || flag?(:solaris) || flag?(:openbsd) || flag?(:dragonfly) %}
      it "raises if trying to write to an IO not opened for writing" do
        IO.pipe do |r, w|
          # unless sync is used the flush on close triggers the exception again
          r.sync = true

          expect_raises(IO::Error, "File not open for writing") do
            r << "hello"
          end
        end
      end
    {% end %}
  end

  {% unless flag?(:without_iconv) %}
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

        it "gets big EUC-JP string" do
          2.times do
            str = ("好我是人\n" * 1000).encode("EUC-JP")
            io = SimpleIOMemory.new(str)
            io.set_encoding("EUC-JP")
            1000.times do
              io.gets.should eq("好我是人")
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
          io = IO::Memory.new("好".encode("EUC-JP"))
          io.set_encoding("EUC-JP")

          buffer = uninitialized UInt8[1024]
          bytes_read = io.read_utf8(buffer.to_slice) # => 3
          bytes_read.should eq(3)
          buffer.to_slice[0, bytes_read].to_a.should eq("好".bytes)
        end

        it "raises on incomplete byte sequence" do
          io = SimpleIOMemory.new("好".byte_slice(0, 1))
          io.set_encoding("EUC-JP")
          expect_raises ArgumentError, "Incomplete multibyte sequence" do
            io.read_char
          end
        end

        it "says invalid byte sequence" do
          io = SimpleIOMemory.new(Slice.new(1, 255_u8))
          io.set_encoding("EUC-JP")
          message =
            {% if flag?(:musl) || flag?(:freebsd) || flag?(:netbsd) || flag?(:dragonfly) %}
              "Incomplete multibyte sequence"
            {% else %}
              "Invalid multibyte sequence"
            {% end %}
          expect_raises(ArgumentError, message) { io.read_char }
        end

        it "skips invalid byte sequences" do
          string = String.build do |str|
            str.write "好".encode("EUC-JP")
            str.write_byte 255_u8
            str.write "是".encode("EUC-JP")
          end
          io = SimpleIOMemory.new(string)
          io.set_encoding("EUC-JP", invalid: :skip)
          io.read_char.should eq('好')
          io.read_char.should eq('是')
          io.read_char.should be_nil
        end

        it "says invalid 'invalid' option" do
          io = SimpleIOMemory.new
          expect_raises ArgumentError, "Valid values for `invalid` option are `nil` and `:skip`, not :foo" do
            io.set_encoding("EUC-JP", invalid: :foo)
          end
        end

        it "says invalid encoding" do
          io = SimpleIOMemory.new("foo")
          io.set_encoding("FOO")
          expect_raises ArgumentError, "Invalid encoding: FOO" do
            io.gets_to_end
          end
        end

        it "sets encoding to utf-8 and stays as UTF-8" do
          io = SimpleIOMemory.new(Base64.decode_string("ey8qx+Tl8fwg7+Dw4Ozl8vD7IOLo5+jy4CovfQ=="))
          io.set_encoding("utf-8")
          io.encoding.should eq("UTF-8")
        end

        it "sets encoding to utf8 and stays as UTF-8" do
          io = SimpleIOMemory.new(Base64.decode_string("ey8qx+Tl8fwg7+Dw4Ozl8vD7IOLo5+jy4CovfQ=="))
          io.set_encoding("utf8")
          io.encoding.should eq("UTF-8")
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
          str = File.read(datapath("io_data_incomplete_multibyte_sequence.txt"))
          m = IO::Memory.new(Base64.decode_string str)
          m.set_encoding("UTF-8", invalid: :skip)
          m.gets_to_end.bytesize.should eq(4277)
        end

        it "decodes incomplete multibyte sequence with skip (3) (#3285)" do
          str = File.read(datapath("io_data_incomplete_multibyte_sequence_2.txt"))
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

        # TODO: Windows networking in the interpreter requires #12495
        {% unless flag?(:interpreted) || flag?(:win32) %}
          it "gets ascii from socket (#9056)" do
            server = TCPServer.new "localhost", 0
            sock = TCPSocket.new "localhost", server.local_address.port
            begin
              sock.set_encoding("ascii")
              spawn do
                client = server.accept
                message = client.gets
                client << "#{message}\n"
              end
              sock << "K\n"
              sock.gets.should eq("K")
            ensure
              server.close
              sock.close
            end
          end
        {% end %}
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
          io.set_encoding("EUC-JP")
          expect_raises ArgumentError, "Invalid multibyte sequence" do
            io.print "\xff"
          end
        end

        it "skips on invalid byte sequence" do
          io = SimpleIOMemory.new
          io.set_encoding("EUC-JP", invalid: :skip)
          io.print "ñ"
          io.print "foo"
        end

        it "raises on incomplete byte sequence" do
          io = SimpleIOMemory.new
          io.set_encoding("EUC-JP")
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
  {% end %}

  describe "#close" do
    it "aborts 'read' in a different fiber" do
      ch = Channel(SpecChannelStatus).new(1)

      IO.pipe do |read, write|
        f = spawn do
          ch.send :begin
          read.gets
        rescue
          ch.send :end
        end

        schedule_timeout ch

        ch.receive.should eq SpecChannelStatus::Begin
        wait_until_blocked f

        read.close
        ch.receive.should eq SpecChannelStatus::End
      end
    end

    it "aborts 'write' in a different fiber" do
      ch = Channel(SpecChannelStatus).new(1)

      IO.pipe do |read, write|
        f = spawn do
          ch.send :begin
          loop do
            write.puts "some line"
          end
        rescue
          ch.send :end
        end

        schedule_timeout ch

        ch.receive.should eq SpecChannelStatus::Begin
        wait_until_blocked f

        write.close
        ch.receive.should eq SpecChannelStatus::End
      end
    end
  end

  describe IO::Error do
    describe ".new" do
      it "accepts `cause` argument (#14241)" do
        cause = Exception.new("cause")
        error = IO::Error.new("foo", cause: cause)
        error.cause.should be cause
      end
    end
  end
end
