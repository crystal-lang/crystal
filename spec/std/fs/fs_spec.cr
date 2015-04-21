require "spec"
require "fs"

macro filesystem_spec(fs)
  it "should combine path using both parts or first" do
    expect({{fs.id}}.combine("foo", "bar")).to eq("foo/bar")
    expect({{fs.id}}.combine("foo", "")).to eq("foo")
    expect({{fs.id}}.combine("", "bar")).to eq("bar")
  end

  it "should list top level folders" do
    expect({{fs.id}}.dirs.map(&.name).sort).to eq(["folder1","folder2"])
  end

  it "should list top level files" do
    expect({{fs.id}}.files.map(&.name)).to eq(["top-level.txt"])
  end

  it "should list top level entries" do
    expect({{fs.id}}.entries.map(&.name).sort).to eq(["folder1","folder2","top-level.txt"])
  end

  it "should have path from filesystem root" do
    expect({{fs.id}}.entry("folder1").path).to eq("folder1")
    expect({{fs.id}}.entry("top-level.txt").path).to eq("top-level.txt")
    expect({{fs.id}}.entry("folder1/subfolder1").path).to eq("folder1/subfolder1")
    expect({{fs.id}}.dir("folder1").entry("subfolder1").path).to eq("folder1/subfolder1")
  end

  it "should list entries inside directory from path" do
    expect({{fs.id}}.find_entries("folder1").map(&.name)).to eq(["subfolder1"])
  end

  it "should tell if existing entry is dir or file" do
    expect({{fs.id}}.entry("folder1").dir?).to be_true
    expect({{fs.id}}.entry("folder1").file?).to be_false

    expect({{fs.id}}.entry("top-level.txt").file?).to be_true
    expect({{fs.id}}.entry("top-level.txt").dir?).to be_false
  end

  it "should read all file" do
    expect({{fs.id}}.file("top-level.txt").read).to eq("Now is the time for all good coders\nto learn Crystal\n")
  end

  it "should check non existing entry" do
    expect({{fs.id}}.exists?("no-existing")).to be_false
    expect({{fs.id}}.exists?("folder1/no-existing.txt")).to be_false
    expect({{fs.id}}.exists?("folder1/no-existing/")).to be_false

    expect({{fs.id}}.exists?("folder1")).to be_true
    expect({{fs.id}}.exists?("folder1/subfolder1")).to be_true
  end

  it "should get if dir exists using dir?" do
    expect({{fs.id}}.dir?("no-existing")).to be_false
    expect({{fs.id}}.dir?("folder1/no-existing.txt")).to be_false
    expect({{fs.id}}.dir?("folder1/no-existing/")).to be_false

    expect({{fs.id}}.dir?("folder1")).to be_true
    expect({{fs.id}}.dir?("folder1/subfolder1")).to be_true
    expect({{fs.id}}.dir?("top-level.txt")).to be_false
  end


  it "should get if file exists using file?" do
    expect({{fs.id}}.file?("no-existing")).to be_false
    expect({{fs.id}}.file?("folder1/no-existing.txt")).to be_false
    expect({{fs.id}}.file?("folder1/no-existing/")).to be_false

    expect({{fs.id}}.file?("folder1")).to be_false
    expect({{fs.id}}.file?("folder1/subfolder1")).to be_false
    expect({{fs.id}}.file?("folder2/second-level.txt")).to be_true
    expect({{fs.id}}.file?("top-level.txt")).to be_true
  end
end

describe "DirectoryFileSystem" do
  fs = FS::DirectoryFileSystem.new "#{__DIR__}/resources"

  filesystem_spec(fs)
end

describe "MemoryFileSystem" do
  fs = FS::MemoryFileSystem.new

  fs.add_directory "folder1" do |folder1|
    folder1.add_directory "subfolder1"
  end
  fs.add_directory "folder2" do |folder2|
    folder2.add_file "second-level.txt", ""
  end
  fs.add_file "top-level.txt", "Now is the time for all good coders\nto learn Crystal\n"

  filesystem_spec(fs)
end

describe "EmbebedMemoryFileSystem" do
  fs = embed_fs("#{__DIR__}/resources")

  filesystem_spec(fs)
end
