#!/usr/bin/env bin/crystal -run
require "spec"

describe "ENV" do
  it "gets non existent var" do
    ENV["NON-EXISTENT"].should be_nil
  end

  it "set and gets" do
    ENV["FOO"] = "1"
    ENV["FOO"].should eq("1")
  end
end
