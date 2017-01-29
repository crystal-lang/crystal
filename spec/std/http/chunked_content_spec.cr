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
end
