require "spec"

describe "BufferedIO" do
  it "does gets" do
    io = BufferedIO.new(StringIO.new("hello\nworld\n"))
    io.gets.should eq("hello\n")
    io.gets.should eq("world\n")
    io.gets.should be_nil
  end

  it "does gets with big line" do
    big_line = "a" * 20_000
    io = BufferedIO.new(StringIO.new("#{big_line}\nworld\n"))
    io.gets.should eq("#{big_line}\n")
  end

  it "does gets with char delimiter" do
    io = BufferedIO.new(StringIO.new("hello world"))
    io.gets('w').should eq("hello w")
    io.gets('r').should eq("or")
    io.gets('r').should eq("ld")
    io.gets('r').should be_nil
  end

  it "does gets with unicode char delimiter" do
    io = BufferedIO.new(StringIO.new("こんにちは"))
    io.gets('ち').should eq("こんにち")
    io.gets('ち').should eq("は")
    io.gets('ち').should be_nil
  end

  it "does puts" do
    str = StringIO.new
    io = BufferedIO.new(str)
    io.puts "Hello"
    str.to_s.should eq("")
    io.flush
    str.to_s.should eq("Hello\n")
  end

  it "does puts with big string" do
    str = StringIO.new
    io = BufferedIO.new(str)
    s = "*" * 20_000
    io << "hello"
    io << s
    io.flush
    str.to_s.should eq("hello#{s}")
  end

  it "does puts many times" do
    str = StringIO.new
    io = BufferedIO.new(str)
    10_000.times { io << "hello" }
    io.flush
    str.to_s.should eq("hello" * 10_000)
  end

  it "writes bytes" do
    str = StringIO.new
    io = BufferedIO.new(str)
    10_000.times { io.write_byte 'a'.ord.to_u8 }
    io.flush
    str.to_s.should eq("a" * 10_000)
  end

  it "does read" do
    io = BufferedIO.new(StringIO.new("hello world"))
    io.read(5).should eq("hello")
    io.read(10).should eq(" world")
    io.read(5).should eq("")
  end

  it "reads char" do
    io = BufferedIO.new(StringIO.new("hi 世界"))
    io.read_char.should eq('h')
    io.read_char.should eq('i')
    io.read_char.should eq(' ')
    io.read_char.should eq('世')
    io.read_char.should eq('界')
    io.read_char.should be_nil
  end

  it "reads byte" do
    io = BufferedIO.new(StringIO.new("hello"))
    io.read_byte.should eq('h'.ord)
    io.read_byte.should eq('e'.ord)
    io.read_byte.should eq('l'.ord)
    io.read_byte.should eq('l'.ord)
    io.read_byte.should eq('o'.ord)
    io.read_char.should be_nil
  end

  it "does new with block" do
    str = StringIO.new
    res = BufferedIO.new str, &.print "Hello"
    res.should be(str)
    str.to_s.should eq("Hello")
  end

  it "rewindws" do
    str = StringIO.new("hello\nworld\n")
    io = BufferedIO.new str
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
    io = BufferedIO.new(StringIO.new(s))

    slice = Slice(UInt8).new(9000)
    count = io.read(slice, 9000)
    count.should eq(9000)

    900.times do
      10.times do |i|
        slice[i].should eq('a'.ord + i)
      end
    end
  end

  it "flushes on \n" do
    str = StringIO.new
    io = BufferedIO.new(str)
    io.flush_on_newline = true

    io << "hello\nworld"
    str.to_s.should eq("hello\n")
    io.flush
    str.to_s.should eq("hello\nworld")
  end

  it "doesn't write past count" do
    str = StringIO.new
    io = BufferedIO.new(str)
    io.flush_on_newline = true

    slice = Slice.new(10) { |i| i == 9 ? '\n'.ord.to_u8 : ('a'.ord + i).to_u8 }
    io.write slice, 4
    io.flush
    str.to_s.should eq("abcd")
  end

  it "syncs" do
    str = StringIO.new

    io = BufferedIO.new(str)
    io.sync?.should be_false

    io.sync = true
    io.sync?.should be_true

    io.write_byte 1_u8

    str.read_byte.should eq(1_u8)
  end
end
