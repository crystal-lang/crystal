#!/usr/bin/env bin/crystal -run
require "spec"

describe "Float" do
  describe "**" do
    assert { (2.5_f32 ** 2).should eq(6.25_f32) }
    assert { (2.5_f32 ** 2.5_f32).should eq(9.882117688026186_f32) }
    assert { (2.5_f32 ** 2.5).should eq(9.882117688026186_f32) }
  end

  describe "round" do
    assert { 2.5.round.should eq(3) }
    assert { 2.4.round.should eq(2) }
  end
end