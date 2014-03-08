#!/usr/bin/env bin/crystal --run
require "spec"

describe "Thread" do
  it "allows passing an argumentless fun to execute" do
    a = 0
    thread = Thread.new -> { a = 1 }
    thread.join
    a.should eq(1)
  end

  it "allows passing a fun with an argument to execute" do
    a = 0
    thread = Thread.new 3, ->(i : Int32) { a += i }
    thread.join
    a.should eq(3)
  end
end
