#!/usr/bin/env bin/crystal -run
require "spec"

describe "Enumerable" do
  describe "find" do
    it "finds" do
      [1, 2, 3].find { |x| x > 2 }.should eq(3)
    end

    it "doesn't find" do
      [1, 2, 3].find { |x| x > 3 }.should be_nil
    end

    it "doesn't find with default value" do
      [1, 2, 3].find(-1) { |x| x > 3 }.should eq(-1)
    end
  end

  describe "inject" do
    assert { [1, 2, 3].inject { |memo, i| memo + i }.should eq(6) }
    assert { [1, 2, 3].inject(10) { |memo, i| memo + i }.should eq(16) }
  end

  describe "min" do
    assert { [1, 2, 3].min.should eq(1) }
  end

  describe "max" do
    assert { [1, 2, 3].max.should eq(3) }
  end

  describe "minmax" do
    assert { [1, 2, 3].minmax.should eq([1, 3]) }
  end

  describe "min_by" do
    assert { [1, 2, 3].min_by { |x| -x }.should eq(3) }
  end

  describe "max_by" do
    assert { [-1, -2, -3].max_by { |x| -x }.should eq(-3) }
  end

  describe "minmax_by" do
    assert { [-1, -2, -3].minmax_by { |x| -x }.should eq([-1, -3]) }
  end

  describe "take" do
    assert { [-1, -2, -3].take(1).should eq([-1]) }
    assert { [-1, -2, -3].take(4).should eq([-1, -2, -3]) }
  end

  describe "first" do
    assert { [-1, -2, -3].first.should eq(-1) }
    assert { [-1, -2, -3].first(1).should eq([-1]) }
    assert { [-1, -2, -3].first(4).should eq([-1, -2, -3]) }
  end

  describe "one?" do
    assert { [1, 2, 2, 3].one? { |x| x == 1 }.should eq(true) }
    assert { [1, 2, 2, 3].one? { |x| x == 2 }.should eq(false) }
    assert { [1, 2, 2, 3].one? { |x| x == 0 }.should eq(false) }
  end

  describe "none?" do
    assert { [1, 2, 2, 3].none? { |x| x == 1 }.should eq(false) }
    assert { [1, 2, 2, 3].none? { |x| x == 0 }.should eq(true) }
  end

  describe "group_by" do
    assert { [1, 2, 2, 3].group_by { |x| x == 2 }.should eq({true => [2, 2], false => [1, 3]}) }
  end

  describe "partition" do
    assert { [1, 2, 2, 3].partition { |x| x == 2 }.should eq([[2, 2], [1, 3]]) }
  end

end
