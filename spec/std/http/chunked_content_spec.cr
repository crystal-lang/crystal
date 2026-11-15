require "spec"
require "http/content"

private class FragmentedChunkedIO < IO::Memory
  def read(slice : Bytes) : Int32
    super(slice[0, Math.min(slice.size, 1)])
  end
end

describe HTTP::ChunkedContent do
  it "reads chunk delimiters split across short reads" do
    io = FragmentedChunkedIO.new("1\r\nA\r\n1\r\nB\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(io)

    content.gets_to_end.should eq "AB"
    io.pos.should eq io.bytesize
  end

  it "delays reading the next chunk as soon as one is consumed (#3270)" do
    mem = IO::Memory.new("4\r\n123\n\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)
    bytes = uninitialized UInt8[4]
    bytes_read = content.read(bytes.to_slice)
    bytes_read.should eq(4)
    String.new(bytes.to_slice).should eq("123\n")
    mem.pos.should eq(7) # only this chunk was read
  end

  it "peeks" do
    mem = IO::Memory.new("4\r\n123\n\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.peek.should eq("123\n".to_slice)
    content.skip(4)
    content.peek.should eq Bytes.empty
  end

  it "peeks into next chunk" do
    mem = IO::Memory.new("4\r\n123\n\r\n3\r\n456\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(4)
    content.peek.should eq("456".to_slice)
    content.gets_to_end.should eq("456")
  end

  it "skips" do
    mem = IO::Memory.new("4\r\n123\n\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(2)
    content.read_char.should eq('3')

    expect_raises(IO::EOFError) do
      content.skip(10)
    end
  end

  it "skips (2)" do
    mem = IO::Memory.new("4\r\n123\n\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(2)
    content.gets_to_end.should eq("3\n")
  end

  it "skips (3)" do
    mem = IO::Memory.new("4\r\n123\n\r\n3\r\n456\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(4)
    content.gets_to_end.should eq("456")
  end

  it "#gets reads multiple chunks" do
    mem = IO::Memory.new("1\r\nA\r\n1\r\nB\r\n0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.gets.should eq "AB"
    mem.pos.should eq mem.bytesize
  end

  it "#read reads empty content" do
    mem = IO::Memory.new("0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.read(Bytes.new(5)).should eq 0
    mem.pos.should eq mem.bytesize
  end

  it "#read_byte reads empty content" do
    mem = IO::Memory.new("0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.read_byte.should be_nil
    mem.pos.should eq mem.bytesize
  end

  it "#peek reads empty content" do
    mem = IO::Memory.new("0\r\n\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.peek.should eq Bytes.empty
    mem.pos.should eq mem.bytesize
  end

  it "#read handles interrupted io" do
    mem = IO::Memory.new("3\r\n123\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(3)
    expect_raises IO::EOFError do
      content.read Bytes.new(5)
    end
  end

  it "#read_byte handles interrupted io" do
    mem = IO::Memory.new("3\r\n123\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(3)
    expect_raises IO::EOFError do
      content.read_byte
    end
  end

  it "#peek handles interrupted io" do
    mem = IO::Memory.new("3\r\n123\r\n")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(3)
    expect_raises IO::EOFError do
      content.peek
    end
  end

  it "#read handles empty data" do
    mem = IO::Memory.new("3\r\n")
    content = HTTP::ChunkedContent.new(mem)

    expect_raises IO::EOFError do
      content.read Bytes.new(1)
    end
  end

  it "#read_byte handles empty data" do
    mem = IO::Memory.new("3\r\n")
    content = HTTP::ChunkedContent.new(mem)

    expect_raises IO::Error do
      content.read_byte
    end
  end

  it "#peek handles empty data" do
    mem = IO::Memory.new("3\r\n")
    content = HTTP::ChunkedContent.new(mem)

    expect_raises IO::EOFError do
      content.peek
    end
  end

  it "handles empty io" do
    mem = IO::Memory.new("")
    chunked = HTTP::ChunkedContent.new(mem)
    expect_raises IO::EOFError do
      chunked.gets
    end
  end

  it "skips chunk extensions" do
    mem = IO::Memory.new(%(1;progress=50;foo="bar"\r\nA\r\n1;progress=100\r\nB\r\n0\r\n\r\n"))
    chunked = HTTP::ChunkedContent.new(mem)
    chunked.gets(2).should eq "AB"
  end

  it "accepts syntactically valid chunk extensions" do
    escapable = ['\t'] + (' '..'~').to_a + ((0x80.chr)..(0xff.chr)).to_a
    quotable = (escapable + ['!'] + ('#'..'[').to_a + (']'..'~').to_a).uniq
    [
      "",
      ";foo",
      ";foo;bar",
      %(;0123456789abcdefghijklmnopqrstuvwxyz!#$%&'*+-.^_`|~),
      " \t ;  \t\tfoo",
      ";foo=bar",
      ";foo \t =  \t\tbar",
      ";foo=bar;arg",
      ";foo=bar\t ;\t arg",
      %(;name=0123456789abcdefghijklmnopqrstuvwxyz!#$%&'*+-.^_`|~),
      %(;name \t =\t \t 0123456789abcdefghijklmnopqrstuvwxyz!#$%&'*+-.^_`|~),
      %(;quoted=""),
      %(;quoted \t=\t ""),
      %(;name="\\""),
      %(;name="#{quotable.map { |char| char.in?('"', '\\') ? "\\#{char}" : char }.join}"),
      %(;name="#{escapable.map { |char| "\\#{char}" }.join}"),
    ].each do |extension|
      mem = IO::Memory.new("1#{extension}\r\nZ\r\n")
      chunked = HTTP::ChunkedContent.new(mem)
      chunked.gets(1).should eq("Z")
    end
  end

  it "rejects syntactically invalid chunk extensions" do
    [
      " ",
      "\t",
      ";",
      "; ",
      ";\t",
      "; =",
      ";=\t",
      ";=value",
      ";key=",
      ";key= ",
      ";key= \t",
      ";key=value;",
      ";key=value; ",
      ";key=value ",
      ";key=value\t",
      ";key value",
      ";key=two words",
      ";key=\"unterminated",
      ";key=\"value\"junk",
      ";key=\"bad\u0001\"",
      ";key=\"bad\\\u007f\"",
      ";key=;foo",
    ].each do |extension|
      mem = IO::Memory.new("1#{extension}\r\nA\r\n0\r\n\r\n")
      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises(IO::Error, "Invalid HTTP chunked content: invalid chunk line") { chunked.gets(1) }
    end
  end

  it "rejects lone LF/CR in chunk-line" do
    [
      "1\nA\r\n",
      "1\rA\r\n",
      "3;foo\nbar\r\nbaz\r\n",
      "3;foo\rbar\r\nbaz\r\n",
    ].each do |line|
      chunked = HTTP::ChunkedContent.new(IO::Memory.new(line))
      expect_raises(IO::Error, "Invalid HTTP chunked content: invalid chunk line") { chunked.gets(1) }
    end
  end

  describe "trailing headers" do
    it "rejects lone LF terminating an empty trailer part" do
      mem = IO::Memory.new("0\r\n\n")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises(IO::Error) { chunked.gets_to_end }
    end

    it "rejects lone LF terminating a trailer header line" do
      mem = IO::Memory.new("0\r\nAdditional-Header: Foo\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises(IO::Error) { chunked.gets_to_end }
    end

    it "rejects lone LF terminating a nonempty trailer part" do
      mem = IO::Memory.new("0\r\nAdditional-Header: Foo\r\n\n")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises(IO::Error) { chunked.gets_to_end }
    end

    it "reads chunked trailer part" do
      mem = IO::Memory.new("0\r\nAdditional-Header: Foo\r\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem)
      chunked.gets.should be_nil
      mem.gets.should be_nil
      chunked.headers.should eq HTTP::Headers{"Additional-Header" => "Foo"}
    end

    it "fails if unterminated chunked trailer part" do
      mem = IO::Memory.new("0\r\nAdditional-Header: Foo")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises(IO::Error) { chunked.gets }
    end

    it "fails on invalid trailer" do
      mem = IO::Memory.new("0\r\nFoo\r\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises IO::Error, "Invalid HTTP chunked content: invalid trailer" do
        chunked.gets
      end
    end

    it "fails on invalid trailer value" do
      mem = IO::Memory.new("0\r\nAdditional-Header: \0\r\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises ArgumentError, "Header content contains invalid character" do
        chunked.gets
      end
    end

    it "fails on invalid trailer key" do
      mem = IO::Memory.new("0\r\nFoo\0: Bar\r\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem)
      expect_raises ArgumentError, "Invalid header name" do
        chunked.gets
      end
    end
  end

  describe "long trailer part" do
    it "fails for long single header" do
      mem = IO::Memory.new("0\r\nFoo: Bar Baz Qux\r\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem, max_headers_size: 12)
      expect_raises(IO::Error, "Invalid HTTP chunked content: invalid trailer") { chunked.gets }
      chunked.headers.should be_empty
    end

    it "fails for long combined headers" do
      mem = IO::Memory.new("0\r\nFoo: Bar\r\nBaz: Qux\r\n\r\n")

      chunked = HTTP::ChunkedContent.new(mem, max_headers_size: 12)
      expect_raises(IO::Error, "Invalid HTTP chunked content: invalid trailer") { chunked.gets }
      chunked.headers.should eq HTTP::Headers{"Foo" => "Bar"}
    end
  end

  it "fails if not properly delimited" do
    mem = IO::Memory.new("0\r\n")

    chunked = HTTP::ChunkedContent.new(mem)
    expect_raises IO::EOFError do
      chunked.gets
    end
  end

  it "fails if not properly delimited" do
    mem = IO::Memory.new("1\r\nA\r\n0\r\n")

    chunked = HTTP::ChunkedContent.new(mem)
    expect_raises IO::EOFError do
      chunked.gets
    end
  end

  it "accepts valid chunk-size" do
    [
      "0",
      "1",
      "05",
      "a",
      "00b",
      "5b",
      "FF",
      "Ab5C",
    ].each do |size|
      value = "." * size.to_i(16)
      content = HTTP::ChunkedContent.new(IO::Memory.new("#{size}\r\n#{value}\r\n0\r\n\r\n"))
      content.gets_to_end.should eq(value)
    end

    # expect EOF to skip allocating, streaming and comparing 2GB
    content = HTTP::ChunkedContent.new(IO::Memory.new("7fffffff\r\n..."))
    expect_raises(IO::EOFError) { content.gets_to_end }
  end

  it "rejects invalid chunk-size" do
    ["+6", "-5", "-c", "+D", "-1", "+0", "-0", " 6", "6 ", "0x6", "6_0", "", "G"].each do |size|
      content = HTTP::ChunkedContent.new(IO::Memory.new("#{size}\r\n..."))
      expect_raises IO::Error, "Invalid HTTP chunked content: invalid chunk line" do
        content.gets
      end
    end
  end

  it "rejects chunk-size overflowing Int32" do
    [
      "80000000",
      "80000001",
      "8fffffff",
      "ffffffff",
      "100000000",
      "10000000000000000",
    ].each do |size|
      content = HTTP::ChunkedContent.new(IO::Memory.new("#{size}\r\n\r\n"))
      expect_raises IO::Error, "Invalid HTTP chunked content: invalid chunk line" do
        content.read_byte
      end
    end
  end

  it "#read stops reading after final chunk" do
    mem = IO::Memory.new("0\r\n\r\n1\r\nA\r\n0\r\n\r\n")

    chunked = HTTP::ChunkedContent.new(mem)
    chunked.read(Bytes.new(8)).should eq 0
    mem.pos.should eq 5
    chunked.read(Bytes.new(8)).should eq 0
    mem.pos.should eq 5
  end

  it "#read_byte stops reading after final chunk" do
    mem = IO::Memory.new("0\r\n\r\n1\r\nA\r\n0\r\n\r\n")

    chunked = HTTP::ChunkedContent.new(mem)
    chunked.read_byte.should be_nil
    mem.pos.should eq 5
    chunked.read_byte.should be_nil
    mem.pos.should eq 5
  end

  it "#peek stops reading after final chunk" do
    mem = IO::Memory.new("0\r\n\r\n1\r\nA\r\n0\r\n\r\n")

    chunked = HTTP::ChunkedContent.new(mem)
    chunked.peek.should eq Bytes.empty
    mem.pos.should eq 5
    chunked.peek.should eq Bytes.empty
    mem.pos.should eq 5
  end
end
