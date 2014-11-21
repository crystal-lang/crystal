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

  it "does puts" do
    str = StringIO.new
    io = BufferedIO.new(str)
    io.puts "Hello"
    str.to_s.should eq("")
    io.flush
    str.to_s.should eq("Hello\n")
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
end
