#!/usr/bin/env bin/crystal --run
require "spec"

describe "StringBuffer" do
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

  it "appends a buffer with count" do
    str = String.build do |io|
      io.append("hello".cstr, 3)
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
    s1 = StringBuffer.new
    s1 << "hello"

    s2 = StringBuffer.new
    s1.to_s(s2)
    s2.to_s.should eq("hello")
  end
end
