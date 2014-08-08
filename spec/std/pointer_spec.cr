#!/usr/bin/env bin/crystal --run
require "spec"

describe "Pointer" do
  it "does malloc with value" do
    p1 = Pointer.malloc(4, 1)
    4.times do |i|
      p1[i].should eq(1)
    end
  end

  it "does malloc with value from block" do
    p1 = Pointer.malloc(4) { |i| i }
    4.times do |i|
      p1[i].should eq(i)
    end
  end

  it "does index with count" do
    p1 = Pointer.malloc(4) { |i| i ** 2 }
    p1.as_enumerable(4).index(4).should eq(2)
    p1.as_enumerable(4).index(5).should be_nil
  end

  describe "copy_from" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p2.copy_from(p1, 4)
      4.times do |i|
        p2[0].should eq(p1[0])
      end
    end
  end

  describe "copy_to" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p1.copy_to(p2, 4)
      4.times do |i|
        p2[0].should eq(p1[0])
      end
    end
  end

  describe "move_from" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).move_from(p1 + 2, 2)
      p1[0].should eq(0)
      p1[1].should eq(2)
      p1[2].should eq(3)
      p1[3].should eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).move_from(p1 + 1, 2)
      p1[0].should eq(0)
      p1[1].should eq(1)
      p1[2].should eq(1)
      p1[3].should eq(2)
    end
  end

  describe "move_to" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).move_to(p1 + 1, 2)
      p1[0].should eq(0)
      p1[1].should eq(2)
      p1[2].should eq(3)
      p1[3].should eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).move_to(p1 + 2, 2)
      p1[0].should eq(0)
      p1[1].should eq(1)
      p1[2].should eq(1)
      p1[3].should eq(2)
    end
  end

  describe "memcmp" do
    assert do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { |i| i }
      p3 = Pointer.malloc(4) { |i| i + 1 }

      p1.memcmp(p2, 4).should be_true
      p1.memcmp(p3, 4).should be_false
    end
  end

  it "compares two pointers by address" do
    p1 = Pointer(Int32).malloc(1)
    p2 = Pointer(Int32).malloc(1)
    p1.should eq(p1)
    p1.should_not eq(p2)
    p1.should_not eq(1)
  end

  it "does to_s" do
    Pointer(Int32).null.to_s.should eq("Pointer(Int32).null")
    Pointer(Int32).new(1234_u64).to_s.should eq("Pointer(Int32)@4d2")
  end

  it "shuffles!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1}
    a.shuffle!(3)

    (a[0] + a[1] + a[2]).should eq(6)

    3.times do |i|
      a.as_enumerable(3).includes?(i + 1).should be_true
    end
  end

  it "maps!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1}
    a.map!(3) { |i| i + 1 }
    a[0].should eq(2)
    a[1].should eq(3)
    a[2].should eq(4)
  end

  it "raises if mallocs negative size" do
    expect_raises ArgumentError { Pointer.malloc(-1, 0) }
  end
end
