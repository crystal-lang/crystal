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

  it "appends a c string" do
    str = String.build do |io|
      io.append_c_string("hello".cstr)
    end
    str.should eq("hello")
  end

  it "appends a byte" do
    str = String.build do |io|
      io << 'a'.ord.to_u8
    end
    str.should eq("a")
  end
end
