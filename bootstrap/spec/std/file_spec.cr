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
  end
end
