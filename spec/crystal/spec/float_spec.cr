#!/usr/bin/env bin/crystal -run
require "spec"

describe "Float" do
  describe "**" do
    it { (2.5 ** 2).should eq(6.25) }
    it { (2.5 ** 2.5).should eq(9.882117688026186) }
  end
end