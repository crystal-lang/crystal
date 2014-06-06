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

  describe "lcm" do
    assert { 2.lcm(2).should eq(2) }
    assert { 3.lcm(-7).should eq(21) }
    assert { 4.lcm(6).should eq(12) }
    assert { 0.lcm(2).should eq(0) }
    assert { 2.lcm(0).should eq(0) }
  end

  describe "to_s" do
    assert { 123.to_s.should eq("123") }
    assert { 12.to_s(2).should eq("1100") }
    assert { -12.to_s(2).should eq("-1100") }
    assert { -123456.to_s(2).should eq("-11110001001000000") }
    assert { 1234.to_s(16).should eq("4d2") }
    assert { -1234.to_s(16).should eq("-4d2") }
    assert { 1234.to_s(36).should eq("ya") }
    assert { -1234.to_s(36).should eq("-ya") }
    assert { 0.to_s(16).should eq("0") }
  end

  describe "bit" do
    assert { 5.bit(0).should eq(1) }
    assert { 5.bit(1).should eq(0) }
    assert { 5.bit(2).should eq(1) }
    assert { 5.bit(3).should eq(0) }
  end

  describe "divmod" do
    assert { 5.divmod(3).should eq({1, 2}) }
  end

  describe "~" do
    assert { (~1).should eq(-2) }
    assert { (~1_u32).should eq(4294967294) }
  end

  describe "to" do
    it "does upwards" do
      a = 0
      1.to(3) { |i| a += i }
      a.should eq(6)
    end

    it "does downards" do
      a = 0
      4.to(2) { |i| a += i }
      a.should eq(9)
    end

    it "does when same" do
      a = 0
      2.to(2) { |i| a += i }
      a.should eq(2)
    end
  end
end
