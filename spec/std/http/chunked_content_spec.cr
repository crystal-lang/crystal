require "spec"
require "http/content"

describe HTTP::ChunkedContent do
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

  it "#read handles interrupted io" do
    mem = IO::Memory.new("3\r\n123\n\r")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(3)
    expect_raises IO::Error, "ChunkedContent misses chunk remaining" do
      content.read Bytes.new(5)
    end
  end

  it "#read_byte handles interrupted io" do
    mem = IO::Memory.new("3\r\n123\n\r")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(3)
    expect_raises IO::Error, "ChunkedContent misses chunk remaining" do
      content.read_byte
    end
  end

  it "#peek handles interrupted io" do
    mem = IO::Memory.new("3\r\n123\n\r")
    content = HTTP::ChunkedContent.new(mem)

    content.skip(3)
    expect_raises IO::Error, "ChunkedContent misses chunk remaining" do
      content.peek
    end
  end

  it "#read handles empty data" do
    mem = IO::Memory.new("3\r\n")
    content = HTTP::ChunkedContent.new(mem)

    expect_raises IO::Error, "ChunkedContent missing data (expected 3 more bytes)" do
      content.read Bytes.new(1)
    end
  end

  it "#read_byte handles empty data" do
    mem = IO::Memory.new("3\r\n")
    content = HTTP::ChunkedContent.new(mem)

    expect_raises IO::Error, "ChunkedContent missing data (expected 3 more bytes)" do
      content.read_byte
    end
  end

  it "#peek handles empty data" do
    mem = IO::Memory.new("3\r\n")
    content = HTTP::ChunkedContent.new(mem)

    expect_raises IO::Error, "ChunkedContent missing data (expected 3 more bytes)" do
      content.peek
    end
  end

  it "handles empty io" do
    mem = IO::Memory.new("")
    expect_raises IO::Error, "ChunkedContent misses chunk remaining" do
      HTTP::ChunkedContent.new(mem)
    end
  end
end
