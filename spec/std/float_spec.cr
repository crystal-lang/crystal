#!/usr/bin/env bin/crystal --run
require "spec"

describe "Float" do
  describe "**" do
    assert { (2.5_f32 ** 2).should eq(6.25_f32) }
    assert { (2.5_f32 ** 2.5_f32).should eq(9.882117688026186_f32) }
    assert { (2.5_f32 ** 2.5).should eq(9.882117688026186_f32) }
    assert { (2.5_f64 ** 2).should eq(6.25_f64) }
    assert { (2.5_f64 ** 2.5_f64).should eq(9.882117688026186_f64) }
    assert { (2.5_f64 ** 2.5).should eq(9.882117688026186_f64) }
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

  describe "to_s" do
    it "does to_s for f32 and f64" do
      12.34.to_s.should eq("12.34")
      12.34_f64.to_s.should eq("12.34")
    end
  end

  describe "hash" do
    it "does for Float32" do
      1.2_f32.hash.should_not eq(0)
    end

    it "does for Float64" do
      1.2.hash.should_not eq(0)
    end
  end

  it "casts" do
    Float32.cast(1_f64).should be_a(Float32)
    Float32.cast(1_f64).should eq(1)

    Float64.cast(1_f32).should be_a(Float64)
    Float64.cast(1_f32).should eq(1)
  end
end
