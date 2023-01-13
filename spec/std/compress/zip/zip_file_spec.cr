require "../../spec_helper"
require "compress/zip"

describe Compress::Zip do
  it "reads file from memory" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.add "foo.txt", "contents of foo"
      zip.add "bar.txt", "contents of bar"
    end

    io.rewind

    Compress::Zip::File.open(io) do |zip|
      entries = zip.entries
      entries.size.should eq(2)

      foo = entries[0]
      foo.filename.should eq("foo.txt")

      bar = entries[1]
      bar.filename.should eq("bar.txt")

      zip["foo.txt"].filename.should eq("foo.txt")
      zip["bar.txt"].filename.should eq("bar.txt")
      zip["baz.txt"]?.should be_nil

      foo.open do |foo_io|
        bar.open do |bar_io|
          foo_io.gets_to_end.should eq("contents of foo")
          bar_io.gets_to_end.should eq("contents of bar")
        end
      end
    end
  end

  it "reads file from file system" do
    filename = datapath("file.zip")

    begin
      File.open(filename, "w") do |file|
        Compress::Zip::Writer.open(file) do |zip|
          zip.add "foo.txt", "contents of foo"
          zip.add "bar.txt", "contents of bar"
        end
      end

      File.open(filename, "r") do |file|
        Compress::Zip::File.open(file) do |zip|
          entries = zip.entries
          entries.size.should eq(2)

          foo = entries[0]
          foo.filename.should eq("foo.txt")

          bar = entries[1]
          bar.filename.should eq("bar.txt")

          zip["foo.txt"].filename.should eq("foo.txt")
          zip["bar.txt"].filename.should eq("bar.txt")
          zip["baz.txt"]?.should be_nil

          foo.open do |foo_io|
            bar.open do |bar_io|
              foo_io.gets_to_end.should eq("contents of foo")
              bar_io.gets_to_end.should eq("contents of bar")
            end
          end
        end
      end
    ensure
      File.delete(filename)
    end
  end

  it "writes comment" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.add Compress::Zip::Writer::Entry.new("foo.txt", comment: "some comment"),
        "contents of foo"
    end

    io.rewind

    Compress::Zip::File.open(io) do |zip|
      zip["foo.txt"].comment.should eq("some comment")
    end
  end

  it "reads big file" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      100.times do |i|
        zip.add "foo#{i}.txt", "some contents #{i}"
      end
    end

    io.rewind

    Compress::Zip::File.open(io) do |zip|
      zip.entries.size.should eq(100)
    end
  end

  it "reads zip file with different extra in local file header and central directory header" do
    Compress::Zip::File.open(datapath("test.zip")) do |zip|
      zip.entries.size.should eq(2)
      zip["one.txt"].open(&.gets_to_end).should eq("One")
      zip["two.txt"].open(&.gets_to_end).should eq("Two")
    end
  end

  it "reads zip comment" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      zip.comment = "zip comment"
    end

    io.rewind

    Compress::Zip::File.open(io) do |zip|
      zip.comment.should eq("zip comment")
    end
  end

  it "writes over int16 files to make sure we can parse" do
    io = IO::Memory.new

    Compress::Zip::Writer.open(io) do |zip|
      0_u16.upto(UInt16::MAX - 1).each do |index|
        zip.add Compress::Zip::Writer::Entry.new("foo_#{index}.txt", comment: "some comment"),
          "contents of foo"
      end
    end

    io.rewind

    Compress::Zip::File.open(io) do |zip|
      zip.entries.size.should eq(UInt16::MAX)
    end
  end

  typeof(Compress::Zip::File.new("file.zip"))
  typeof(Compress::Zip::File.open("file.zip") { })
end
