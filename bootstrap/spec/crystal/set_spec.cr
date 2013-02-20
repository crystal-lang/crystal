#!/usr/bin/env bin/crystal -run
require "spec"
require "set"

describe "Set" do
  describe "set" do
    it "is empty" do
      Set.new.empty?.should be_true
    end

    it "has length 0" do
      Set.new.length.should eq(0)
    end
  end

  describe "add" do
    it "adds and includes" do
      set = Set.new
      set.add 1
      set.includes?(1).should be_true
      set.length.should eq(1)
    end
  end
end
