#!/usr/bin/env bin/crystal --run
require "spec"

describe "Int" do
  describe "**" do
    assert { (2 ** 2).should eq(4) }
    assert { (2 ** 2.5_f32).should eq(5.656854249492381) }
    assert { (2 ** 2.5).should eq(5.656854249492381) }
  end

  describe "divisible_by?" do
    assert { 10.divisible_by?(5).should be_true }
    assert { 10.divisible_by?(3).should be_false }
  end

  describe "even?" do
    assert { 2.even?.should be_true }
    assert { 3.even?.should be_false }
  end

  describe "odd?" do
    assert { 2.odd?.should be_false }
    assert { 3.odd?.should be_true }
  end

  describe "abs" do
    it "does for signed" do
      1_i8.abs.should eq(1_i8)
      -1_i8.abs.should eq(1_i8)
      1_i16.abs.should eq(1_i16)
      -1_i16.abs.should eq(1_i16)
      1_i32.abs.should eq(1_i32)
      -1_i32.abs.should eq(1_i32)
      1_i64.abs.should eq(1_i64)
      -1_i64.abs.should eq(1_i64)
    end

    it "does for unsigned" do
      1_u8.abs.should eq(1_u8)
      1_u16.abs.should eq(1_u16)
      1_u32.abs.should eq(1_u32)
      1_u64.abs.should eq(1_u64)
    end
  end
end
