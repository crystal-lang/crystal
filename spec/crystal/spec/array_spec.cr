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
end
