require "spec"
require "tar"

describe Tar do
  it "reads existing tar" do
    Tar::Reader.open("#{__DIR__}/../data/tar/test.tar") do |tar|
      entry = tar.next_entry.not_nil!
      entry.name.should eq("one.txt")
      entry.size.should eq(3)
      entry.uname.should eq("asterite-manas")
      entry.gname.should eq("staff")
      entry.uid.should eq(501)
      entry.mode.should eq(420)
      entry.gid.should eq(20)
      entry.devmajor.should eq(0)
      entry.devminor.should eq(0)
      entry.linkname.should eq("")
      entry.type.should eq(Tar::Header::Type::REG)
      entry.modification_time.year.should eq(2017)
      entry.io.gets_to_end.should eq("One")

      entry = tar.next_entry.not_nil!
      entry.name.should eq("two.txt")
      entry.io.gets_to_end.should eq("Two")

      tar.next_entry.should be_nil
    end
  end

  it "writes and read a tar in memory" do
    io = IO::Memory.new

    Tar::Writer.open(io) do |tar|
      header = Tar::Header.new
      header.name = "foo.txt"
      header.size = 10
      tar.add(header) do |io|
        io << "1234567890"
      end
    end

    io.rewind

    Tar::Reader.open(io) do |tar|
      entry = tar.next_entry.not_nil!
      entry.name.should eq("foo.txt")
      entry.size.should eq(10)
      entry.io.gets_to_end.should eq("1234567890")

      tar.next_entry.should be_nil
    end
  end

  it "writes with long name" do
    io = IO::Memory.new

    long_prefix = "foo/bar/q/" * 15
    name = "#{long_prefix}filename"

    Tar::Writer.open(io) do |tar|
      header = Tar::Header.new
      header.name = name
      header.size = 0
      tar.add(header) { }
    end

    io.rewind

    Tar::Reader.open(io) do |tar|
      entry = tar.next_entry.not_nil!
      entry.name.should eq(name)
    end
  end

  it "writes with various convenience methods" do
    io = IO::Memory.new

    Tar::Writer.open(io) do |tar|
      tar.add_dir "foo", 0o123
      tar.add "foo/one.txt", 0o234, "One"
      tar.add "foo/two.txt", 0o345, "Two".to_slice
    end

    io.rewind

    Tar::Reader.open(io) do |tar|
      entry = tar.next_entry.not_nil!
      entry.name.should eq("foo/")
      entry.dir?.should be_true
      entry.mode.should eq(0o123)
      entry.io.gets_to_end.should eq("")

      entry = tar.next_entry.not_nil!
      entry.name.should eq("foo/one.txt")
      entry.type.should eq(Tar::Header::Type::REG)
      entry.mode.should eq(0o234)
      entry.io.gets_to_end.should eq("One")

      entry = tar.next_entry.not_nil!
      entry.name.should eq("foo/two.txt")
      entry.type.should eq(Tar::Header::Type::REG)
      entry.mode.should eq(0o345)
      entry.io.gets_to_end.should eq("Two")

      tar.next_entry.should be_nil
    end
  end

  it "reads directory" do
    Tar::Reader.open("#{__DIR__}/../data/tar/directory.tar") do |tar|
      entry = tar.next_entry.not_nil!
      entry.name.should eq("a/")
      entry.dir?.should be_true

      entry = tar.next_entry.not_nil!
      entry.name.should eq("a/b/")
      entry.dir?.should be_true

      entry = tar.next_entry.not_nil!
      entry.name.should eq("a/c")
      entry.dir?.should be_false
      entry.io.gets_to_end.should eq("c\n")

      tar.next_entry.should be_nil
    end
  end

  it "reads empty_filename" do
    Tar::Reader.open("#{__DIR__}/../data/tar/empty_filename.tar") do |tar|
      entry = tar.next_entry.not_nil!
      entry.name.should eq("")

      tar.next_entry.should be_nil
    end
  end

  pending "reads pax" do
    Tar::Reader.open("#{__DIR__}/../data/tar/pax.tar") do |tar|
      while entry = tar.next_entry
        p entry.type
      end
    end
  end

  it "reads spaces" do
    pp File.size("#{__DIR__}/../data/tar/spaces.tar")

    Tar::Reader.open("#{__DIR__}/../data/tar/spaces.tar") do |tar|
      while entry = tar.next_entry
        p entry
      end
    end
  end

  pending "reads sparse" do
    Tar::Reader.open("#{__DIR__}/../data/tar/sparse.tar") do |tar|
      while entry = tar.next_entry
        p entry
      end
    end
  end

  pending "reads sparse" do
    Tar::Reader.open("#{__DIR__}/../data/tar/xattrs.tar") do |tar|
      while entry = tar.next_entry
        p entry
      end
    end
  end
end
