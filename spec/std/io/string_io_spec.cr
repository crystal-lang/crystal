require "spec"

describe "StringIO" do
  it "appends a char" do
    str = String.build do |io|
      io << 'a'
    end
    expect(str).to eq("a")
  end

  it "appends a string" do
    str = String.build do |io|
      io << "hello"
    end
    expect(str).to eq("hello")
  end

  it "writes to a buffer with count" do
    str = String.build do |io|
      io.write Slice.new("hello".cstr, 3)
    end
    expect(str).to eq("hel")
  end

  it "appends a byte" do
    str = String.build do |io|
      io.write_byte 'a'.ord.to_u8
    end
    expect(str).to eq("a")
  end

  it "appends to another buffer" do
    s1 = StringIO.new
    s1 << "hello"

    s2 = StringIO.new
    s1.to_s(s2)
    expect(s2.to_s).to eq("hello")
  end

  it "writes" do
    io = StringIO.new
    io << "foo" << "bar"
    expect(io.to_s).to eq("foobar")
  end

  it "puts" do
    io = StringIO.new
    io.puts "foo"
    expect(io.to_s).to eq("foo\n")
  end

  it "print" do
    io = StringIO.new
    io.print "foo"
    expect(io.to_s).to eq("foo")
  end

  it "reads single line content" do
    io = StringIO.new("foo")
    expect(io.gets).to eq("foo")
  end

  it "reads each line" do
    io = StringIO.new("foo\r\nbar\r\n")
    expect(io.gets).to eq("foo\r\n")
    expect(io.gets).to eq("bar\r\n")
    expect(io.gets).to eq(nil)
  end

  it "gets with char as delimiter" do
    io = StringIO.new("hello world")
    expect(io.gets('w')).to eq("hello w")
    expect(io.gets('r')).to eq("or")
    expect(io.gets('r')).to eq("ld")
    expect(io.gets('r')).to eq(nil)
  end

  it "reads all remaining content" do
    io = StringIO.new("foo\nbar\nbaz\n")
    expect(io.gets).to eq("foo\n")
    expect(io.read).to eq("bar\nbaz\n")
  end

  it "reads utf-8 string" do
    io = StringIO.new("há日本語")
    expect(io.gets).to eq("há日本語")
  end

  it "reads N chars" do
    io = StringIO.new("foobarbaz")
    expect(io.read(3)).to eq("foo")
    expect(io.read(50)).to eq("barbaz")
  end

  it "write single byte" do
    io = StringIO.new
    io.write_byte 97_u8
    expect(io.to_s).to eq("a")
  end

  it "writes and reads" do
    io = StringIO.new
    io << "foo" << "bar"
    expect(io.gets).to eq("foobar")
  end

  it "does puts" do
    io = StringIO.new
    io.puts
    expect(io.to_s).to eq("\n")
  end

  it "read chars from UTF-8 string" do
    io = StringIO.new("há日本語")
    expect(io.read_char).to eq('h')
    expect(io.read_char).to eq('á')
    expect(io.read_char).to eq('日')
    expect(io.read_char).to eq('本')
    expect(io.read_char).to eq('語')
    expect(io.read_char).to eq(nil)
  end

  it "does each_line" do
    io = StringIO.new("a\nbb\ncc")
    counter = 0
    io.each_line do |line|
      case counter
      when 0
        expect(line).to eq("a\n")
      when 1
        expect(line).to eq("bb\n")
      when 2
        expect(line).to eq("cc")
      end
      counter += 1
    end
    expect(counter).to eq(3)
  end

  it "writes an array of btyes" do
    str = String.build do |io|
      bytes = ['a'.ord.to_u8, 'b'.ord.to_u8]
      io.write bytes
    end
    expect(str).to eq("ab")
  end

  it "raises on EOF with read_line" do
    str = StringIO.new("hello")
    expect(str.read_line).to eq("hello")

    expect_raises IO::EOFError, "end of file reached" do
      str.read_line
    end
  end

  it "raises on EOF with readline and delimiter" do
    str = StringIO.new("hello")
    expect(str.read_line('e')).to eq("he")
    expect(str.read_line('e')).to eq("llo")

    expect_raises IO::EOFError, "end of file reached" do
      str.read_line
    end
  end

  it "writes with printf" do
    str = StringIO.new
    str.printf "Hello %d", 123
    expect(str.to_s).to eq("Hello 123")
  end

  it "writes with printf as an array" do
    str = StringIO.new
    str.printf "Hello %d", [123]
    expect(str.to_s).to eq("Hello 123")
  end
end
