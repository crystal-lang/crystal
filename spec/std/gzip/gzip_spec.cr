require "spec"
require "gzip"

describe Gzip do
  it "writes and reads to memory" do
    io = IO::Memory.new

    time = Time.utc(2016, 1, 2)
    os = 4_u8
    extra = Bytes[1, 2, 3]
    name = "foo.txt"
    comment = "some comment"
    contents = "hello world"

    Gzip::Writer.open(io) do |gzip|
      header = gzip.header
      header.modification_time = time
      header.os = os
      header.extra = extra
      header.name = name
      header.comment = comment

      io.bytesize.should eq(0)
      gzip.flush
      io.bytesize.should_not eq(0)

      gzip.print contents
    end

    io.rewind

    Gzip::Reader.open(io) do |gzip|
      header = gzip.header.not_nil!
      header.modification_time.should eq(time)
      header.os.should eq(os)
      header.extra.should eq(extra)
      header.name.should eq(name)
      header.comment.should eq(comment)

      # Reading zero bytes is OK
      gzip.read(Bytes.empty).should eq(0)

      gzip.gets_to_end.should eq(contents)
    end
  end
end
