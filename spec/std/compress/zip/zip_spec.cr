require "../../spec_helper"
require "compress/zip"

describe Compress::Zip do
  it "writes and reads to memory" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", &.print("contents of foo")
      zip.add "bar.txt", &.print("contents of bar")
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.file?.should be_true
      entry.dir?.should be_false
      entry.filename.should eq("foo.txt")
      entry.compression_method.should eq(Compress::Zip::CompressionMethod::DEFLATED)
      entry.crc32.should eq(0)
      entry.compressed_size.should eq(0)
      entry.uncompressed_size.should eq(0)
      entry.extra.should be_empty
      entry.io.gets_to_end.should eq("contents of foo")

      entry = zip.next_entry.not_nil!
      entry.filename.should eq("bar.txt")
      entry.io.gets_to_end.should eq("contents of bar")

      zip.next_entry.should be_nil
    end
  end

  it "writes entry" do
    io = IO::Memory.new

    time = Time.utc(2017, 1, 14, 2, 3, 4)
    extra = Bytes[1, 2, 3, 4]

    Compress::Zip::Writer.open(io) do |zip|
      zip.add(Compress::Zip::Writer::Entry.new("foo.txt", time: time, extra: extra)) do |io|
        io.print("contents of foo")
      end
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.time.should eq(time)
      entry.extra.should eq(extra)
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes entry uncompressed" do
    io = IO::Memory.new

    text = "contents of foo"
    crc32 = Digest::CRC32.checksum(text)

    Compress::Zip::Writer.open(io) do |zip|
      entry = Compress::Zip::Writer::Entry.new("foo.txt")
      entry.compression_method = Compress::Zip::CompressionMethod::STORED
      entry.crc32 = crc32
      entry.compressed_size = text.bytesize.to_u32
      entry.uncompressed_size = text.bytesize.to_u32
      zip.add entry, &.print(text)

      entry = Compress::Zip::Writer::Entry.new("bar.txt")
      entry.compression_method = Compress::Zip::CompressionMethod::STORED
      entry.crc32 = crc32
      entry.compressed_size = text.bytesize.to_u32
      entry.uncompressed_size = text.bytesize.to_u32
      zip.add entry, &.print(text)
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.compression_method.should eq(Compress::Zip::CompressionMethod::STORED)
      entry.crc32.should eq(crc32)
      entry.compressed_size.should eq(text.bytesize)
      entry.uncompressed_size.should eq(text.bytesize)
      entry.io.gets_to_end.should eq(text)

      entry = zip.next_entry.not_nil!
      entry.filename.should eq("bar.txt")
      entry.io.gets_to_end.should eq(text)
    end
  end

  it "writes entry uncompressed and reads with Compress::Zip::File" do
    io = IO::Memory.new

    text = "contents of foo"
    crc32 = Digest::CRC32.checksum(text)

    Compress::Zip::Writer.open(io) do |zip|
      entry = Compress::Zip::Writer::Entry.new("foo.txt")
      entry.compression_method = Compress::Zip::CompressionMethod::STORED
      entry.crc32 = crc32
      entry.compressed_size = text.bytesize.to_u32
      entry.uncompressed_size = text.bytesize.to_u32
      zip.add entry, &.print(text)
    end

    io.rewind

    Compress::Zip::File.open(io) do |zip|
      zip.entries.size.should eq(1)
      entry = zip.entries.first
      entry.filename.should eq("foo.txt")
      entry.open(&.gets_to_end).should eq(text)
    end
  end

  it "adds a directory" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.add_dir "one"
      zip.add_dir "two/"
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("one/")
      entry.file?.should be_false
      entry.dir?.should be_true
      entry.io.gets_to_end.should eq("")

      entry = zip.next_entry.not_nil!
      entry.filename.should eq("two/")
      entry.dir?.should be_true
      entry.io.gets_to_end.should eq("")
    end
  end

  it "writes string" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", "contents of foo"
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes bytes" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", "contents of foo".to_slice
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes io" do
    io = IO::Memory.new
    data = IO::Memory.new("contents of foo")

    Compress::Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", data
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes file" do
    io = IO::Memory.new
    filename = datapath("test_file.txt")

    Compress::Zip::Writer.open(io) do |zip|
      file = File.open(filename)
      zip.add "foo.txt", file
      file.closed?.should be_true
    end

    io.rewind

    Compress::Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq(File.read(filename))
    end
  end

  typeof(Compress::Zip::Reader.new("file.zip"))
  typeof(Compress::Zip::Reader.open("file.zip") { })

  typeof(Compress::Zip::Writer.new("file.zip"))
  typeof(Compress::Zip::Writer.open("file.zip") { })
end
