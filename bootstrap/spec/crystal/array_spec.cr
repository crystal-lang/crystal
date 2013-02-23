#!/usr/bin/env bin/crystal -run
require "spec"

describe "Array" do
  describe "empty" do
    it "is empty" do
      [].empty?.should be_true
    end

    it "has length 0" do
      [].length.should eq(0)
    end
  end

  describe "==" do
    it "compare empty" do
      [].should eq([])
      [1].should_not eq([])
      [].should_not eq([1])
    end

    it "compare elements" do
      [1, 2, 3].should eq([1, 2, 3])
      [1, 2, 3].should_not eq([3, 2, 1])
    end
  end

  describe "inspect" do
    assert { [1, 2, 3].inspect.should eq("[1, 2, 3]") }
  end

  describe "+" do
    assert do
      a = [1, 2, 3]
      b = [4, 5]
      c = a + b
      c.length.should eq(5)
      0.upto(4) { |i| c[i].should eq(i + 1) }
    end
  end

  describe "index" do
    it "performs without a block" do
      a = [1, 2, 3]
      a.index(3).should eq(2)
      a.index(4).should eq(-1)
    end

    it "performs with a block" do
      a = [1, 2, 3]
      a.index { |i| i > 1 }.should eq(1)
      a.index { |i| i > 3 }.should eq(-1)
    end
  end
end
