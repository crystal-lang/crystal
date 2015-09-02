require "spec"

# This is a non-optimized version of StringIO so we can test
# raw IO. Optimizations for specific IOs are tested separately
# (for example in buffered_io_spec)
class SimpleStringIO
  include IO

  getter buffer
  getter bytesize

  def initialize(capacity = 64)
    @buffer = GC.malloc_atomic(capacity.to_u32) as UInt8*
    @bytesize = 0
    @capacity = capacity
    @pos = 0
  end

  def self.new(string : String)
    io = new(string.bytesize)
    io << string
    io
  end

  def read(slice : Slice(UInt8))
    count = slice.length
    count = Math.min(count, @bytesize - @pos)
    slice.copy_from(@buffer + @pos, count)
    @pos += count
    count
  end

  def write(slice : Slice(UInt8))
    count = slice.length
    new_bytesize = bytesize + count
    if new_bytesize > @capacity
      resize_to_capacity(Math.pw2ceil(new_bytesize))
    end

    slice.copy_to(@buffer + @bytesize, count)
    @bytesize += count

    count
  end

  private def check_needs_resize
    resize_to_capacity(@capacity * 2) if @bytesize == @capacity
  end

  private def resize_to_capacity(capacity)
    @capacity = capacity
    @buffer = @buffer.realloc(@capacity)
  end
end

private def with_pipe
  read, write = IO.pipe
  yield read, write
ensure
  read.close if read rescue nil
  write.close if write rescue nil
end

describe IO do
  describe ".select" do
    it "returns the available readable ios" do
      with_pipe do |read, write|
        write.puts "hey"
        write.close
        IO.select({read}).includes?(read).should be_true
      end
    end

    it "returns the available writable ios" do
      with_pipe do |read, write|
        IO.select(nil, {write}).includes?(write).should be_true
      end
    end

    it "times out" do
      with_pipe do |read, write|
        IO.select({read}, nil, nil, 0.00001).should be_nil
      end
    end
  end

  describe "IO iterators" do
    it "iterates by line" do
      io = StringIO.new("hello\nbye\n")
      lines = io.each_line
      lines.next.should eq("hello\n")
      lines.next.should eq("bye\n")
      lines.next.should be_a(Iterator::Stop)

      lines.rewind
      lines.next.should eq("hello\n")
    end

    it "iterates by char" do
      io = StringIO.new("abあぼ")
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
      io = StringIO.new("ab")
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
    src = StringIO.new(string)
    dst = StringIO.new
    IO.copy(src, dst).should eq(string.bytesize)
    dst.to_s.should eq(string)
  end

  it "reopens" do
    File.open("#{__DIR__}/../data/test_file.txt") do |file1|
      File.open("#{__DIR__}/../data/test_file.ini") do |file2|
        file2.reopen(file1)
        file2.gets.should eq("Hello World\n")
      end
    end
  end

  describe "read operations" do
    it "does gets" do
      io = SimpleStringIO.new("hello\nworld\n")
      io.gets.should eq("hello\n")
      io.gets.should eq("world\n")
      io.gets.should be_nil
    end

    it "does gets with big line" do
      big_line = "a" * 20_000
      io = SimpleStringIO.new("#{big_line}\nworld\n")
      io.gets.should eq("#{big_line}\n")
    end

    it "does gets with char delimiter" do
      io = SimpleStringIO.new("hello world")
      io.gets('w').should eq("hello w")
      io.gets('r').should eq("or")
      io.gets('r').should eq("ld")
      io.gets('r').should be_nil
    end

    it "does gets with unicode char delimiter" do
      io = SimpleStringIO.new("こんにちは")
      io.gets('ち').should eq("こんにち")
      io.gets('ち').should eq("は")
      io.gets('ち').should be_nil
    end

    it "gets with string as delimiter" do
      io = SimpleStringIO.new("hello world")
      io.gets("lo").should eq("hello")
      io.gets("rl").should eq(" worl")
      io.gets("foo").should eq("d")
    end

    it "gets with empty string as delimiter" do
      io = SimpleStringIO.new("hello\nworld\n")
      io.gets("").should eq("hello\nworld\n")
    end

    it "gets with single byte string as delimiter" do
      io = SimpleStringIO.new("hello\nworld\nbye")
      io.gets("\n").should eq("hello\n")
      io.gets("\n").should eq("world\n")
      io.gets("\n").should eq("bye")
    end

    it "does gets with limit" do
      io = SimpleStringIO.new("hello\nworld\n")
      io.gets(3).should eq("hel")
      io.gets(10_000).should eq("lo\n")
      io.gets(10_000).should eq("world\n")
      io.gets(3).should be_nil
    end

    it "does gets with char and limit" do
      io = SimpleStringIO.new("hello\nworld\n")
      io.gets('o', 2).should eq("he")
      io.gets('w', 10_000).should eq("llo\nw")
      io.gets('z', 10_000).should eq("orld\n")
      io.gets('a', 3).should be_nil
    end

    it "raises if invoking gets with negative limit" do
      io = SimpleStringIO.new("hello\nworld\n")
      expect_raises ArgumentError, "negative limit" do
        io.gets(-1)
      end
    end

    it "does read_line with limit" do
      io = SimpleStringIO.new("hello\nworld\n")
      io.read_line(3).should eq("hel")
      io.read_line(10_000).should eq("lo\n")
      io.read_line(10_000).should eq("world\n")
      expect_raises(IO::EOFError) { io.read_line(3) }
    end

    it "does read_line with char and limit" do
      io = SimpleStringIO.new("hello\nworld\n")
      io.read_line('o', 2).should eq("he")
      io.read_line('w', 10_000).should eq("llo\nw")
      io.read_line('z', 10_000).should eq("orld\n")
      expect_raises(IO::EOFError) { io.read_line('a', 3) }
    end

    it "reads all remaining content" do
      io = SimpleStringIO.new("foo\nbar\nbaz\n")
      io.gets.should eq("foo\n")
      io.read.should eq("bar\nbaz\n")
    end

    it "does read with limit" do
      io = SimpleStringIO.new("hello world")
      io.read(5).should eq("hello")
      io.read(10).should eq(" world")
      io.read(5).should eq("")
    end

    it "raises argument error if reads negative count" do
      io = SimpleStringIO.new("hello world")
      expect_raises(ArgumentError, "negative count") do
        io.read(-1)
      end
    end

    it "reads char" do
      io = SimpleStringIO.new("hi 世界")
      io.read_char.should eq('h')
      io.read_char.should eq('i')
      io.read_char.should eq(' ')
      io.read_char.should eq('世')
      io.read_char.should eq('界')
      io.read_char.should be_nil
    end

    it "reads byte" do
      io = SimpleStringIO.new("hello")
      io.read_byte.should eq('h'.ord)
      io.read_byte.should eq('e'.ord)
      io.read_byte.should eq('l'.ord)
      io.read_byte.should eq('l'.ord)
      io.read_byte.should eq('o'.ord)
      io.read_char.should be_nil
    end

    it "does each_line" do
      io = SimpleStringIO.new("a\nbb\ncc")
      counter = 0
      io.each_line do |line|
        case counter
        when 0
          line.should eq("a\n")
        when 1
          line.should eq("bb\n")
        when 2
          line.should eq("cc")
        end
        counter += 1
      end
      counter.should eq(3)
    end

    it "raises on EOF with read_line" do
      str = SimpleStringIO.new("hello")
      str.read_line.should eq("hello")

      expect_raises IO::EOFError, "end of file reached" do
        str.read_line
      end
    end

    it "raises on EOF with readline and delimiter" do
      str = SimpleStringIO.new("hello")
      str.read_line('e').should eq("he")
      str.read_line('e').should eq("llo")

      expect_raises IO::EOFError, "end of file reached" do
        str.read_line
      end
    end

    it "does read_fully" do
      str = SimpleStringIO.new("hello")
      slice = Slice(UInt8).new(4)
      str.read_fully(slice)
      String.new(slice).should eq("hell")

      expect_raises(IO::EOFError) do
        str.read_fully(slice)
      end
    end
  end

  describe "write operations" do
    it "does puts" do
      io = SimpleStringIO.new
      io.puts "Hello"
      io.read.should eq("Hello\n")
    end

    it "does puts with big string" do
      io = SimpleStringIO.new
      s = "*" * 20_000
      io << "hello"
      io << s
      io.read.should eq("hello#{s}")
    end

    it "does puts many times" do
      io = SimpleStringIO.new
      10_000.times { io << "hello" }
      io.read.should eq("hello" * 10_000)
    end

    it "puts several arguments" do
      io = SimpleStringIO.new
      io.puts(1, "aaa", "\n")
      io.read.should eq("1\naaa\n\n")
    end

    it "prints" do
      io = SimpleStringIO.new
      io.print "foo"
      io.read.should eq("foo")
    end

    it "prints several arguments" do
      io = SimpleStringIO.new
      io.print "foo", "bar", "baz"
      io.read.should eq("foobarbaz")
    end

    it "writes bytes" do
      io = SimpleStringIO.new
      10_000.times { io.write_byte 'a'.ord.to_u8 }
      io.read.should eq("a" * 10_000)
    end

    it "writes an array of bytes" do
      io = SimpleStringIO.new
      io.write ['a'.ord.to_u8, 'b'.ord.to_u8]
      io.read.should eq("ab")
    end

    it "writes with printf" do
      io = SimpleStringIO.new
      io.printf "Hello %d", 123
      io.read.should eq("Hello 123")
    end

    it "writes with printf as an array" do
      io = SimpleStringIO.new
      io.printf "Hello %d", [123]
      io.read.should eq("Hello 123")
    end
  end
end
