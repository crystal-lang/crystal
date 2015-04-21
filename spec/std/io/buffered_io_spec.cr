require "spec"

describe "BufferedIO" do
  it "does gets" do
    io = BufferedIO.new(StringIO.new("hello\nworld\n"))
    expect(io.gets).to eq("hello\n")
    expect(io.gets).to eq("world\n")
    expect(io.gets).to be_nil
  end

  it "does gets with big line" do
    big_line = "a" * 20_000
    io = BufferedIO.new(StringIO.new("#{big_line}\nworld\n"))
    expect(io.gets).to eq("#{big_line}\n")
  end

  it "does gets with char delimiter" do
    io = BufferedIO.new(StringIO.new("hello world"))
    expect(io.gets('w')).to eq("hello w")
    expect(io.gets('r')).to eq("or")
    expect(io.gets('r')).to eq("ld")
    expect(io.gets('r')).to be_nil
  end

  it "does gets with unicode char delimiter" do
    io = BufferedIO.new(StringIO.new("こんにちは"))
    expect(io.gets('ち')).to eq("こんにち")
    expect(io.gets('ち')).to eq("は")
    expect(io.gets('ち')).to be_nil
  end

  it "does puts" do
    str = StringIO.new
    io = BufferedIO.new(str)
    io.puts "Hello"
    expect(str.to_s).to eq("")
    io.flush
    expect(str.to_s).to eq("Hello\n")
  end

  it "does read" do
    io = BufferedIO.new(StringIO.new("hello world"))
    expect(io.read(5)).to eq("hello")
    expect(io.read(10)).to eq(" world")
    expect(io.read(5)).to eq("")
  end

  it "reads char" do
    io = BufferedIO.new(StringIO.new("hi 世界"))
    expect(io.read_char).to eq('h')
    expect(io.read_char).to eq('i')
    expect(io.read_char).to eq(' ')
    expect(io.read_char).to eq('世')
    expect(io.read_char).to eq('界')
    expect(io.read_char).to be_nil
  end

  it "reads byte" do
    io = BufferedIO.new(StringIO.new("hello"))
    expect(io.read_byte).to eq('h'.ord)
    expect(io.read_byte).to eq('e'.ord)
    expect(io.read_byte).to eq('l'.ord)
    expect(io.read_byte).to eq('l'.ord)
    expect(io.read_byte).to eq('o'.ord)
    expect(io.read_char).to be_nil
  end

  it "does new with block" do
    str = StringIO.new
    res = BufferedIO.new str, &.print "Hello"
    expect(res).to be(str)
    expect(str.to_s).to eq("Hello")
  end
end
