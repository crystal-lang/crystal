#!/usr/bin/env bin/crystal --run
require "spec"
require "bit_array"

describe "BitArray" do
  it "is has length" do
    ary = BitArray.new(100)
    ary.length.should eq(100)
  end

  it "is is initially empty" do
    ary = BitArray.new(100)
    100.times do |i|
      ary[i].should be_false
    end
  end

  it "is sets first bit to true" do
    ary = BitArray.new(100)
    ary[0] = true
    ary[0].should be_true
  end

  it "is sets second bit to true" do
    ary = BitArray.new(100)
    ary[1] = true
    ary[1].should be_true
  end

  it "is sets first bit to false" do
    ary = BitArray.new(100)
    ary[0] = true
    ary[0] = false
    ary[0].should be_false
  end

  it "is sets second bit to false" do
    ary = BitArray.new(100)
    ary[1] = true
    ary[1] = false
    ary[1].should be_false
  end

  it "is sets last bit to true with negative index" do
    ary = BitArray.new(100)
    ary[-1] = true
    ary[-1].should be_true
    ary[99].should be_true
  end

  it "is raises when out of bounds" do
    ary = BitArray.new(10)
    begin
      ary[10] = true
      fail "expected IndexOutOfBounds to be raised"
    rescue IndexOutOfBounds
    end
  end

  it "is does to_s" do
    ary = BitArray.new(8)
    ary[0] = true
    ary[2] = true
    ary[4] = true
    ary.to_s.should eq("BitArray[10101000]")
  end
end
