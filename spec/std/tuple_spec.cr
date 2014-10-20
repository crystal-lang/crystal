#!/usr/bin/env bin/crystal --run
require "spec"

class TupleSpecObj
  getter x

  def initialize(@x)
  end

  def clone
    TupleSpecObj.new(@x)
  end
end

describe "Tuple" do
  it "does length" do
    {1, 2, 1, 2}.length.should eq(4)
  end

  it "does []" do
    a = {1, 2.5}
    i = 0
    a[i].should eq(1)
    i = 1
    a[i].should eq(2.5)
  end

  it "does [] raises index out of bounds" do
    a = {1, 2.5}
    i = 2
    expect_raises(IndexOutOfBounds) { a[i] }
    i = -1
    expect_raises(IndexOutOfBounds) { a[i] }
  end

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

  it "does == with differnt types but same length" do
    {1, 2}.should eq({1.0, 2.0})
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

  it "does compare with different lengths" do
    a = {2}
    b = {1, 2, 3}
    c = {1, 2}
    d = {1, 1}
    e = {1, 1, 3}
    [a, b, c, d, e].sort.should eq([d, e, c, b, a])
    [a, b, c, d, e].min.should eq(d)
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

  it "does dup" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.dup
    u.length.should eq(2)
    u[0].should be(r1)
    u[1].should be(r2)
  end

  it "does clone" do
    r1, r2 = TupleSpecObj.new(10), TupleSpecObj.new(20)
    t = {r1, r2}
    u = t.clone
    u.length.should eq(2)
    u[0].x.should eq(r1.x)
    u[0].should_not be(r1)
    u[1].x.should eq(r2.x)
    u[1].should_not be(r2)
  end
end
