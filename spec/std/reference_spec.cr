#!/usr/bin/env bin/crystal --run
require "spec"

describe "Reference" do
  it "compares reference to other reference" do
    o1 = Reference.new
    o2 = Reference.new
    o1.should eq(o1)
    o1.should_not eq(o2)
    o1.should_not eq(1)
  end

  it "should not be nil" do
    Reference.new.nil?.should be_false
  end

  it "should be false when negated" do
    (!Reference.new).should be_false
  end
end
