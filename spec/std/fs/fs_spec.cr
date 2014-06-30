#!/usr/bin/env bin/crystal --run
require "spec"
require "fs"

macro filesystem_spec(fs)
  it "should combine path using both parts or first" do
    {{fs.id}}.combine("foo", "bar").should eq("foo/bar")
    {{fs.id}}.combine("foo", "").should eq("foo")
    {{fs.id}}.combine("", "bar").should eq("bar")
  end

  it "should list top level folders" do
    {{fs.id}}.dirs.map(&.name).should eq(["folder1","folder2"])
  end

  it "should list top level files" do
    {{fs.id}}.files.map(&.name).should eq(["top-level.txt"])
  end

  it "should list top level entries" do
    {{fs.id}}.entries.map(&.name).should eq(["folder1","folder2","top-level.txt"])
  end

  it "should have path from filesystem root" do
    {{fs.id}}.entry("folder1").path.should eq("folder1")
    {{fs.id}}.entry("top-level.txt").path.should eq("top-level.txt")
    {{fs.id}}.entry("folder1/subfolder1").path.should eq("folder1/subfolder1")
    {{fs.id}}.dir("folder1").entry("subfolder1").path.should eq("folder1/subfolder1")
  end

  it "should list entries inside directory from path" do
    {{fs.id}}.find_entries("folder1").map(&.name).should eq(["subfolder1"])
  end

  it "should tell if existing entry is dir or file" do
    {{fs.id}}.entry("folder1").dir?.should be_true
    {{fs.id}}.entry("folder1").file?.should be_false

    {{fs.id}}.entry("top-level.txt").file?.should be_true
    {{fs.id}}.entry("top-level.txt").dir?.should be_false
  end

  it "should read all file" do
    {{fs.id}}.file("top-level.txt").read.should eq("Now is the time for all good coders\nto learn Crystal\n")
  end
end

describe "DirectoryFileSystem" do
  fs = FS::DirectoryFileSystem.new "#{__DIR__}/resources"

  filesystem_spec(fs)
end

describe "MemoryFileSystem" do
  fs = FS::MemoryFileSystem.new

  fs.add_directory "folder1" do |folder1|
    folder1.add_directory "subfolder1" do |subfolder1|
    end
  end
  fs.add_directory "folder2"
  fs.add_file "top-level.txt", "Now is the time for all good coders\nto learn Crystal\n"

  filesystem_spec(fs)
end
