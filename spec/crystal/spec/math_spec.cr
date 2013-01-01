#!/usr/bin/env bin/crystal -run
require "spec"

describe "Math" do
  describe "sqrt" do
    assert { Math.sqrt(4).should eq(2) }
    assert { Math.sqrt(81.0).should eq(9.0) }
  end
end