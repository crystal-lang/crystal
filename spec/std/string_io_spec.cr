#!/usr/bin/env bin/crystal --run
require "spec"

describe "StringIO" do
  it "writes" do
    io = StringIO.new
    io << "foo" << "bar"
    io.to_s.should eq("foobar")
  end

  it "puts" do
    io = StringIO.new
    io.puts "foo"
    io.to_s.should eq("foo\n")
  end

  it "print" do
    io = StringIO.new
    io.print "foo"
    io.to_s.should eq("foo")
  end

  it "reads single line content" do
    io = StringIO.new("foo")
    io.gets.should eq("foo")
  end

  it "reads each line" do
    io = StringIO.new("foo\r\nbar\r\n")
    io.gets.should eq("foo\r\n")
    io.gets.should eq("bar\r\n")
    io.gets.should eq(nil)
  end

  it "reads N chars" do
    io = StringIO.new("foobarbaz")
    io.read(3).should eq("foo")
    io.read(50).should eq("barbaz")
  end
end
