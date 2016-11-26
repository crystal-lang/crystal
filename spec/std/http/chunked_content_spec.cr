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
end
