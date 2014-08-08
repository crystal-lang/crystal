#!/usr/bin/env bin/crystal --run
require "spec"

describe "BufferedIO" do
  it "does gets" do
    io = BufferedIO.new(StringIO.new("hello\nworld\n"))
    io.gets.should eq("hello\n")
    io.gets.should eq("world\n")
    io.gets.should be_nil
  end

  it "does puts" do
    str = StringIO.new
    io = BufferedIO.new(str)
    io.puts "Hello"
    str.to_s.should eq("")
    io.flush
    str.to_s.should eq("Hello\n")
  end
end
