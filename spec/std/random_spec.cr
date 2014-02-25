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
end
