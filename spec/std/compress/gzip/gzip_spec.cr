require "../../spec_helper"
require "compress/gzip"

private SAMPLE_TIME     = Time.utc(2016, 1, 2)
private SAMPLE_OS       = 4_u8
private SAMPLE_EXTRA    = Bytes[1, 2, 3]
private SAMPLE_NAME     = "foo.txt"
private SAMPLE_COMMENT  = "some comment"
private SAMPLE_CONTENTS = "hello world\nfoo bar"

private def new_sample_io
  io = IO::Memory.new

  Compress::Gzip::Writer.open(io) do |gzip|
    header = gzip.header
    header.modification_time = SAMPLE_TIME
    header.os = SAMPLE_OS
    header.extra = SAMPLE_EXTRA
    header.name = SAMPLE_NAME
    header.comment = SAMPLE_COMMENT

    io.bytesize.should eq(0)
    gzip.flush
    io.bytesize.should_not eq(0)

    gzip.print SAMPLE_CONTENTS
  end

  io.rewind
end

describe Compress::Gzip do
  it "writes and reads to memory" do
    io = new_sample_io

    Compress::Gzip::Reader.open(io) do |gzip|
      header = gzip.header.not_nil!
      header.modification_time.should eq(SAMPLE_TIME)
      header.os.should eq(SAMPLE_OS)
      header.extra.should eq(SAMPLE_EXTRA)
      header.name.should eq(SAMPLE_NAME)
      header.comment.should eq(SAMPLE_COMMENT)

      # Reading zero bytes is OK
      gzip.read(Bytes.empty).should eq(0)

      gzip.gets_to_end.should eq(SAMPLE_CONTENTS)
    end
  end

  it "rewinds" do
    io = new_sample_io

    gzip = Compress::Gzip::Reader.new(io)
    gzip.gets.should eq(SAMPLE_CONTENTS.lines.first)

    gzip.rewind
    gzip.gets_to_end.should eq(SAMPLE_CONTENTS)
  end

  it "reads file with extra fields from file system" do
    File.open(datapath("test.gz")) do |file|
      Compress::Gzip::Reader.open(file) do |gzip|
        header = gzip.header.not_nil!
        header.modification_time.to_utc.should eq(Time.utc(2012, 9, 4, 22, 6, 5))
        header.os.should eq(3_u8)
        header.extra.should eq(Bytes[1, 2, 3, 4, 5])
        header.name.should eq("test.txt")
        header.comment.should eq("happy birthday")
        gzip.gets_to_end.should eq("One\nTwo")
      end
    end
  end

  it "writes and reads file with extra fields" do
    io = IO::Memory.new
    Compress::Gzip::Writer.open(io) do |gzip|
      header = gzip.header
      header.modification_time = Time.utc(2012, 9, 4, 22, 6, 5)
      header.os = 3_u8
      header.extra = Bytes[1, 2, 3, 4, 5]
      header.name = "test.txt"
      header.comment = "happy birthday"
      gzip << "One\nTwo"
    end
    io.rewind
    Compress::Gzip::Reader.open(io) do |gzip|
      header = gzip.header.not_nil!
      header.modification_time.to_utc.should eq(Time.utc(2012, 9, 4, 22, 6, 5))
      header.os.should eq(3_u8)
      header.extra.should eq(Bytes[1, 2, 3, 4, 5])
      header.name.should eq("test.txt")
      header.comment.should eq("happy birthday")
      gzip.gets_to_end.should eq("One\nTwo")
    end
  end
end
