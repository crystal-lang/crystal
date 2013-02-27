#!/usr/bin/env bin/crystal -run
require "spec"

describe "Pointer" do
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
end
