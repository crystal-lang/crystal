#!/usr/bin/env bin/crystal -run
require "spec"

describe "StringBuilder" do
  it "concatenates two strings" do
    builder = StringBuilder.new
    builder << "hello"
    builder << "world"
    builder.to_s.should eq("helloworld")
  end
end