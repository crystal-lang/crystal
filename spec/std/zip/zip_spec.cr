require "../spec_helper"
require "zip"

describe Zip do
  it "writes and reads to memory" do
    io = IO::Memory.new

    Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", &.print("contents of foo")
      zip.add "bar.txt", &.print("contents of bar")
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.file?.should be_true
      entry.dir?.should be_false
      entry.filename.should eq("foo.txt")
      entry.compression_method.should eq(Zip::CompressionMethod::DEFLATED)
      entry.crc32.should eq(0)
      entry.compressed_size.should eq(0)
      entry.uncompressed_size.should eq(0)
      entry.extra.empty?.should be_true
      entry.io.gets_to_end.should eq("contents of foo")

      entry = zip.next_entry.not_nil!
      entry.filename.should eq("bar.txt")
      entry.io.gets_to_end.should eq("contents of bar")

      zip.next_entry.should be_nil
    end
  end

  it "writes entry" do
    io = IO::Memory.new

    time = Time.new(2017, 1, 14, 2, 3, 4)
    extra = Bytes[1, 2, 3, 4]

    Zip::Writer.open(io) do |zip|
      zip.add(Zip::Writer::Entry.new("foo.txt", time: time, extra: extra)) do |io|
        io.print("contents of foo")
      end
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
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
    crc32 = CRC32.checksum(text)

    Zip::Writer.open(io) do |zip|
      entry = Zip::Writer::Entry.new("foo.txt")
      entry.compression_method = Zip::CompressionMethod::STORED
      entry.crc32 = crc32
      entry.compressed_size = text.bytesize.to_u32
      entry.uncompressed_size = text.bytesize.to_u32
      zip.add entry, &.print(text)

      entry = Zip::Writer::Entry.new("bar.txt")
      entry.compression_method = Zip::CompressionMethod::STORED
      entry.crc32 = crc32
      entry.compressed_size = text.bytesize.to_u32
      entry.uncompressed_size = text.bytesize.to_u32
      zip.add entry, &.print(text)
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.compression_method.should eq(Zip::CompressionMethod::STORED)
      entry.crc32.should eq(crc32)
      entry.compressed_size.should eq(text.bytesize)
      entry.uncompressed_size.should eq(text.bytesize)
      entry.io.gets_to_end.should eq(text)

      entry = zip.next_entry.not_nil!
      entry.filename.should eq("bar.txt")
      entry.io.gets_to_end.should eq(text)
    end
  end

  it "adds a directory" do
    io = IO::Memory.new

    Zip::Writer.open(io) do |zip|
      zip.add_dir "one"
      zip.add_dir "two/"
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
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

    Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", "contents of foo"
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes bytes" do
    io = IO::Memory.new

    Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", "contents of foo".to_slice
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes io" do
    io = IO::Memory.new
    data = IO::Memory.new("contents of foo")

    Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", data
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq("contents of foo")
    end
  end

  it "writes file" do
    io = IO::Memory.new
    filename = datapath("test_file.txt")

    Zip::Writer.open(io) do |zip|
      file = File.open(filename)
      zip.add "foo.txt", file
      file.closed?.should be_true
    end

    io.rewind

    Zip::Reader.open(io) do |zip|
      entry = zip.next_entry.not_nil!
      entry.filename.should eq("foo.txt")
      entry.io.gets_to_end.should eq(File.read(filename))
    end
  end

  typeof(Zip::Reader.new("file.zip"))
  typeof(Zip::Reader.open("file.zip") { })

  typeof(Zip::Writer.new("file.zip"))
  typeof(Zip::Writer.open("file.zip") { })
end
