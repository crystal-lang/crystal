#!/usr/bin/env bin/crystal -run
require "spec"

describe "Hash" do
  describe "empty" do
    it "length should be zero" do
      {}.length.should eq(0)
    end
  end

  it "sets and gets" do
    a = {}
    a[1] = 2
    a[1].should eq(2)
  end

  it "gets from literal" do
    a = {1 => 2}
    a[1].should eq(2)
  end

  it "gets from union" do
    a = {1 => 2, :foo => 1.1}
    a[1].should eq(2)
  end

  it "get array of keys" do
    a = {}
    a.keys.should eq([])
    a[:foo] = 1
    a[:bar] = 2
    a.keys.should eq([:foo, :bar])
  end
end