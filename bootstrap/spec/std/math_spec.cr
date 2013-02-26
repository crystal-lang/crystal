#!/usr/bin/env bin/crystal -run
require "spec"

describe "Math" do
  describe "sqrt" do
    assert { Math.sqrt(4).should eq(2) }
    assert { Math.sqrt(81.0).should eq(9.0) }
    assert { Math.sqrt(81.0f).should eq(9.0) }
  end

  describe "min" do
    assert { Math.min(1, 2).should eq(1) }
    assert { Math.min(2, 1).should eq(1) }
  end

  describe "max" do
    assert { Math.max(1, 2).should eq(2) }
    assert { Math.max(2, 1).should eq(2) }
  end
end