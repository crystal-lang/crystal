#!/usr/bin/env bin/crystal --run
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

  describe "floor" do
    assert { 2.1.floor.should eq(2) }
    assert { 2.9.floor.should eq(2) }
  end

  describe "ceil" do
    assert { 2.0_f32.ceil.should eq(2) }
    assert { 2.0.ceil.should eq(2) }

    assert { 2.1_f32.ceil.should eq(3_f32) }
    assert { 2.1.ceil.should eq(3) }

    assert { 2.9_f32.ceil.should eq(3) }
    assert { 2.9.ceil.should eq(3) }
  end
end
