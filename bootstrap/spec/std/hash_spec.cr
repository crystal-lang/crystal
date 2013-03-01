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

  describe "==" do
    assert do
      a = {1 => 2, 3 => 4}
      b = {3 => 4, 1 => 2}
      c = {2 => 3}
      a.should eq(a)
      a.should eq(b)
      b.should eq(a)
      a.should_not eq(c)
      c.should_not eq(a)
    end
  end

  describe "fetch" do
    it "fetches with one argument" do
      a = {1 => 2}
      a.fetch(1).should eq(2)
      a.fetch(2).should be_nil
      a.should eq({1 => 2})
    end

    it "fetches with default value" do
      a = {1 => 2}
      a.fetch(1, 3).should eq(2)
      a.fetch(2, 3).should eq(3)
      a.should eq({1 => 2})
    end

    it "fetches with block" do
      a = {1 => 2}
      a.fetch(1) { |k| k * 2 }.should eq(2)
      a.fetch(2) { |k| k * 2 }.should eq(4)
      a.should eq({1 => 2})
    end
  end
end