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

  describe "min_by" do
    assert { [1, 2, 3].min_by { |x| -x }.should eq(3) }
  end

  describe "max_by" do
    assert { [-1, -2, -3].max_by { |x| -x }.should eq(-3) }
  end
end
