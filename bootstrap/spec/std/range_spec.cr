#!/usr/bin/env bin/crystal -run
require "spec"

describe "Range" do
  it "gets basic properties" do
    r = 1 .. 5
    r.begin.should eq(1)
    r.end.should eq(5)
    r.excludes_end?.should be_false

    r = 1 ... 5
    r.begin.should eq(1)
    r.end.should eq(5)
    r.excludes_end?.should be_true
  end

  it "includes?" do
    (1 .. 5).includes?(1).should be_true
    (1 .. 5).includes?(5).should be_true

    (1 ... 5).includes?(1).should be_true
    (1 ... 5).includes?(5).should be_false
  end
end
