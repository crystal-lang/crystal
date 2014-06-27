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
    p1.index(4, 4).should eq(2)
    p1.index(5, 4).should be_nil
  end

  describe "memcpy" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p2.memcpy(p1, 4)
      4.times do |i|
        p2[0].should eq(p1[0])
      end
    end
  end

  describe "memmove" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).memmove(p1 + 2, 2)
      p1[0].should eq(0)
      p1[1].should eq(2)
      p1[2].should eq(3)
      p1[3].should eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).memmove(p1 + 1, 2)
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
end
