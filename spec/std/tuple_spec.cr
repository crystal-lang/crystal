#!/usr/bin/env bin/crystal --run
require "spec"

describe "Tuple" do
  it "does ==" do
    a = {1, 2}
    b = {3, 4}
    c = {1, 2, 3}
    d = {1}
    e = {1, 2}
    a.should eq(a)
    a.should eq(e)
    a.should_not eq(b)
    a.should_not eq(c)
    a.should_not eq(d)
  end

  it "does compare" do
    a = {1, 2}
    b = {3, 4}
    c = {1, 6}
    d = {3, 5}
    e = {0, 8}
    [a, b, c, d, e].sort.should eq([e, a, c, b, d])
    [a, b, c, d, e].min.should eq(e)
  end

  it "does to_s" do
    {1, 2, 3}.to_s.should eq("{1, 2, 3}")
  end

  it "does each" do
    a = 0
    {1, 2, 3}.each do |i|
      a += i
    end
    a.should eq(6)
  end
end
