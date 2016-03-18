require "spec"

class IO::BufferedWrapper
  include IO::Buffered

  getter called_unbuffered_read

  @io : IO
  @called_unbuffered_read : Bool

  def initialize(@io)
    @called_unbuffered_read = false
  end

  def self.new(io)
    buffered_io = new(io)
    yield buffered_io
    buffered_io.flush
    io
  end

  private def unbuffered_read(slice : Slice(UInt8))
    @called_unbuffered_read = true
    @io.read(slice)
  end

  private def unbuffered_write(slice : Slice(UInt8))
    @io.write(slice)
  end

  private def unbuffered_flush
    @io.flush
  end

  def fd
    @io.fd
  end

  private def unbuffered_close
    @io.close
  end

  def closed?
    @io.closed?
  end

  def to_fd_io
    @io.to_fd_io
  end

  private def unbuffered_rewind
    @io.rewind
  end
end

describe "IO::Buffered" do
  it "does gets" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hello\nworld\n"))
    io.gets.should eq("hello\n")
    io.gets.should eq("world\n")
    io.gets.should be_nil
  end

  it "does gets with big line" do
    big_line = "a" * 20_000
    io = IO::BufferedWrapper.new(MemoryIO.new("#{big_line}\nworld\n"))
    io.gets.should eq("#{big_line}\n")
  end

  it "does gets with char delimiter" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hello world"))
    io.gets('w').should eq("hello w")
    io.gets('r').should eq("or")
    io.gets('r').should eq("ld")
    io.gets('r').should be_nil
  end

  it "does gets with unicode char delimiter" do
    io = IO::BufferedWrapper.new(MemoryIO.new("こんにちは"))
    io.gets('ち').should eq("こんにち")
    io.gets('ち').should eq("は")
    io.gets('ち').should be_nil
  end

  it "does gets with limit" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hello\nworld\n"))
    io.gets(3).should eq("hel")
    io.gets(10_000).should eq("lo\n")
    io.gets(10_000).should eq("world\n")
    io.gets(3).should be_nil
  end

  it "does gets with char and limit" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hello\nworld\n"))
    io.gets('o', 2).should eq("he")
    io.gets('w', 10_000).should eq("llo\nw")
    io.gets('z', 10_000).should eq("orld\n")
    io.gets('a', 3).should be_nil
  end

  it "does gets with char and limit when not found in buffer" do
    io = IO::BufferedWrapper.new(MemoryIO.new(("a" * (IO::Buffered::BUFFER_SIZE + 10)) + "b"))
    io.gets('b', 2).should eq("aa")
  end

  it "does gets with char and limit when not found in buffer (2)" do
    base = "a" * (IO::Buffered::BUFFER_SIZE + 10)
    io = IO::BufferedWrapper.new(MemoryIO.new(base + "aabaaa"))
    io.gets('b', IO::Buffered::BUFFER_SIZE + 11).should eq(base + "a")
  end

  it "raises if invoking gets with negative limit" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hello\nworld\n"))
    expect_raises ArgumentError, "negative limit" do
      io.gets(-1)
    end
  end

  it "writes bytes" do
    str = MemoryIO.new
    io = IO::BufferedWrapper.new(str)
    10_000.times { io.write_byte 'a'.ord.to_u8 }
    io.flush
    str.to_s.should eq("a" * 10_000)
  end

  it "reads char" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hi 世界"))
    io.read_char.should eq('h')
    io.read_char.should eq('i')
    io.read_char.should eq(' ')
    io.read_char.should eq('世')
    io.read_char.should eq('界')
    io.read_char.should be_nil
  end

  it "reads byte" do
    io = IO::BufferedWrapper.new(MemoryIO.new("hello"))
    io.read_byte.should eq('h'.ord)
    io.read_byte.should eq('e'.ord)
    io.read_byte.should eq('l'.ord)
    io.read_byte.should eq('l'.ord)
    io.read_byte.should eq('o'.ord)
    io.read_char.should be_nil
  end

  it "does new with block" do
    str = MemoryIO.new
    res = IO::BufferedWrapper.new str, &.print "Hello"
    res.should be(str)
    str.to_s.should eq("Hello")
  end

  it "rewinds" do
    str = MemoryIO.new("hello\nworld\n")
    io = IO::BufferedWrapper.new str
    io.gets.should eq("hello\n")
    io.rewind
    io.gets.should eq("hello\n")
  end

  it "reads more than the buffer's internal capacity" do
    s = String.build do |str|
      900.times do
        10.times do |i|
          str << ('a'.ord + i).chr
        end
      end
    end
    io = IO::BufferedWrapper.new(MemoryIO.new(s))

    slice = Slice(UInt8).new(9000)
    count = io.read(slice)
    count.should eq(9000)

    900.times do
      10.times do |i|
        slice[i].should eq('a'.ord + i)
      end
    end
  end

  it "writes more than the buffer's internal capacity" do
    s = String.build do |str|
      900.times do
        10.times do |i|
          str << ('a'.ord + i).chr
        end
      end
    end
    strio = MemoryIO.new
    strio << s
    strio.rewind
    io = IO::BufferedWrapper.new(strio)
    io.write(s.to_slice)
    strio.rewind.gets_to_end.should eq(s)
  end

  it "does puts" do
    str = MemoryIO.new
    io = IO::BufferedWrapper.new(str)
    io.puts "Hello"
    str.to_s.should eq("")
    io.flush
    str.to_s.should eq("Hello\n")
  end

  it "does puts with big string" do
    str = MemoryIO.new
    io = IO::BufferedWrapper.new(str)
    s = "*" * 20_000
    io << "hello"
    io << s
    io.flush
    str.to_s.should eq("hello#{s}")
  end

  it "does puts many times" do
    str = MemoryIO.new
    io = IO::BufferedWrapper.new(str)
    10_000.times { io << "hello" }
    io.flush
    str.to_s.should eq("hello" * 10_000)
  end

  it "flushes on \n" do
    str = MemoryIO.new
    io = IO::BufferedWrapper.new(str)
    io.flush_on_newline = true

    io << "hello\nworld"
    str.to_s.should eq("hello\n")
    io.flush
    str.to_s.should eq("hello\nworld")
  end

  it "doesn't write past count" do
    str = MemoryIO.new
    io = IO::BufferedWrapper.new(str)
    io.flush_on_newline = true

    slice = Slice.new(10) { |i| i == 9 ? '\n'.ord.to_u8 : ('a'.ord + i).to_u8 }
    io.write slice[0, 4]
    io.flush
    str.to_s.should eq("abcd")
  end

  it "syncs" do
    str = MemoryIO.new

    io = IO::BufferedWrapper.new(str)
    io.sync?.should be_false

    io.sync = true
    io.sync?.should be_true

    io.write_byte 1_u8

    str.rewind
    str.read_byte.should eq(1_u8)
  end

  it "shouldn't call unbuffered read if reading to an empty slice" do
    str = MemoryIO.new("foo")
    io = IO::BufferedWrapper.new(str)
    io.read(Slice(UInt8).new(0))
    io.called_unbuffered_read.should be_false
  end

  describe "encoding" do
    describe "decode" do
      it "gets_to_end" do
        str = "Hello world" * 200
        base_io = MemoryIO.new(str.encode("UCS-2LE"))
        io = IO::BufferedWrapper.new(base_io)
        io.set_encoding("UCS-2LE")
        io.gets_to_end.should eq(str)
      end

      it "gets" do
        str = "Hello world\nFoo\nBar\n" + ("1234567890" * 1000)
        base_io = MemoryIO.new(str.encode("UCS-2LE"))
        io = IO::BufferedWrapper.new(base_io)
        io.set_encoding("UCS-2LE")
        io.gets.should eq("Hello world\n")
        io.gets.should eq("Foo\n")
        io.gets.should eq("Bar\n")
      end

      it "gets big string" do
        str = "Hello\nWorld\n" * 10_000
        base_io = MemoryIO.new(str.encode("UCS-2LE"))
        io = IO::BufferedWrapper.new(base_io)
        io.set_encoding("UCS-2LE")
        10_000.times do |i|
          io.gets.should eq("Hello\n")
          io.gets.should eq("World\n")
        end
      end

      it "gets big GB2312 string" do
        str = ("你好我是人\n" * 1000).encode("GB2312")
        base_io = MemoryIO.new(str)
        io = IO::BufferedWrapper.new(base_io)
        io.set_encoding("GB2312")
        1000.times do
          io.gets.should eq("你好我是人\n")
        end
      end

      it "reads char" do
        str = "x\nHello world" + ("1234567890" * 1000)
        base_io = MemoryIO.new(str.encode("UCS-2LE"))
        io = IO::BufferedWrapper.new(base_io)
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
