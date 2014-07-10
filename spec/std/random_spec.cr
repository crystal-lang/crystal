#!/usr/bin/env bin/crystal --run
require "spec"

describe "Random" do
  it "limited number" do
    rand(1).should eq(0)

    x = rand(2)
    (x >= 0).should be_true
    (x < 2).should be_true
  end

  it "float number" do
    x = rand
    (x > 0).should be_true
    (x < 1).should be_true
  end

  it "raises on invalid number" do
    expect_raises ArgumentError, "incorrect rand value: 0" do
      rand(0)
    end
  end

  it "does with inclusive range" do
    rand(1..1).should eq(1)
    x = rand(1..3)
    (x >= 1).should be_true
    (x <= 3).should be_true
  end

  it "does with exclusive range" do
    rand(1...2).should eq(1)
    x = rand(1...4)
    (x >= 1).should be_true
    (x < 4).should be_true
  end

  it "raises on invalid range" do
    expect_raises ArgumentError, "incorrect rand value: 1...1" do
      rand(1...1)
    end
  end
end
