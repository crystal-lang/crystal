#!/usr/bin/env bin/crystal -run
require "spec"

describe "File" do
  it "reads entire file" do
    str = File.read "#{__DIR__}/data/test_file.txt"
    str.should eq("Hello World\n" * 20)
  end

  it "tests exists? and gives true" do
    File.exists?("#{__DIR__}/data/test_file.txt").should be_true
  end

  it "tests exists? and gives false" do
    File.exists?("#{__DIR__}/data/non_existing_file.txt").should be_false
  end

  it "gets dirname" do
    File.dirname("/Users/foo/bar.cr").should eq("/Users/foo")
    File.dirname("foo").should eq(".")
    File.dirname("").should eq(".")
  end

  it "gets basename" do
    File.basename("/foo/bar/baz.cr").should eq("baz.cr")
    File.basename("/foo/").should eq("foo")
    File.basename("foo").should eq("foo")
    File.basename("").should eq("")
  end

  it "gets basename removing suffix" do
    File.basename("/foo/bar/baz.cr", ".cr").should eq("baz")
  end

  it "gets extname" do
    File.extname("/foo/bar/baz.cr").should eq(".cr")
    File.extname("/foo/bar/baz.cr.cz").should eq(".cz")
    File.extname("/foo/bar/.profile").should eq("")
    File.extname("/foo/bar/.profile.sh").should eq(".sh")
    File.extname("/foo/bar/foo.").should eq("")
    File.extname("test").should eq("")
  end
end
