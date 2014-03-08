#!/usr/bin/env bin/crystal --run
require "spec"

describe "Thread" do
  it "allows passing an argumentless fun to execute" do
    ta = 0
    thread = Thread.new -> { ta = 1; 10 }
    thread.join.should eq(10)
    ta.should eq(1)
  end

  it "allows passing a fun with an argument to execute" do
    tb = 0
    thread = Thread.new 3, ->(i : Int32) { tb += i; 20 }
    thread.join.should eq(20)
    tb.should eq(3)
  end
end
