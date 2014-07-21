#!/usr/bin/env bin/crystal --run
require "spec"

describe "StringIO" do
  it "appends a char" do
    str = String.build do |io|
      io << 'a'
    end
    str.should eq("a")
  end

  it "appends a string" do
    str = String.build do |io|
      io << "hello"
    end
    str.should eq("hello")
  end

  it "writes to a buffer with count" do
    str = String.build do |io|
      io.write "hello".cstr, 3
    end
    str.should eq("hel")
  end

  it "appends a byte" do
    str = String.build do |io|
      io.write_byte 'a'.ord.to_u8
    end
    str.should eq("a")
  end

  it "appends to another buffer" do
    s1 = StringIO.new
    s1 << "hello"

    s2 = StringIO.new
    s1.to_s(s2)
    s2.to_s.should eq("hello")
  end

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

  it "write single byte" do
    io = StringIO.new
    io.write_byte 97_u8
    io.to_s.should eq("a")
  end

  it "writes and reads" do
    io = StringIO.new
    io << "foo" << "bar"
    io.gets.should eq("foobar")
  end
end
