#!/usr/bin/env bin/crystal -run
require "spec"

describe "Int" do
  describe "**" do
    it { (2 ** 2).should eq(4) }
    it { (2 ** 2.5).should eq(5.656854249492381) }
  end
end