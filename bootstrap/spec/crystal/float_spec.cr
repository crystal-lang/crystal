#!/usr/bin/env bin/crystal -run
require "spec"

describe "Float" do
  describe "**" do
    assert { (2.5f ** 2).should eq(6.25f) }
    assert { (2.5f ** 2.5f).should eq(9.882117688026186f) }
    assert { (2.5f ** 2.5).should eq(9.882117688026186f) }
  end
end