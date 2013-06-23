#!/usr/bin/env bin/crystal -run
require "spec"

describe "File" do
  it "reads entire file" do
    str = File.read "#{__DIR__}/data/test_file.txt"
    str.should eq("Hello World\n" * 20)
  end
end
