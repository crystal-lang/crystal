#!/usr/bin/env bin/crystal -run
require "spec"

describe "String" do
  it "compares strings: different length" do
    "foo".should_not eq("fo")
  end

  it "compares strings: same object" do
    f = "foo"
    f.should eq(f)
  end

  it "compares strings: same length, same string" do
    "foo".should eq("fo" + "o")
  end

  it "compares strings: same length, different string" do
    "foo".should_not eq("bar")
  end

  it "interpolates string" do
    foo = "<foo>"
    bar = 123
    "foo #{bar}".should eq("foo 123")
    "foo #{ bar}".should eq("foo 123")
    "#{foo} bar".should eq("<foo> bar")
  end
end