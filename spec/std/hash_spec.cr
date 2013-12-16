#!/usr/bin/env bin/crystal --run
require "spec"

describe "Hash" do
  describe "empty" do
    it "length should be zero" do
      h = {} of Int32 => Int32
      h.length.should eq(0)
      h.empty?.should be_true
    end
  end

  it "sets and gets" do
    a = {} of Int32 => Int32
    a[1] = 2
    a[1].should eq(2)
  end

  it "gets from literal" do
    a = {1 => 2}
    a[1].should eq(2)
  end

  # pending
  # it "gets from union" do
  #   a = {1 => 2, :foo => 1.1}
  #   a[1].should eq(2)
  # end

  it "gets nilable" do
    a = {1 => 2}
    a[1]?.should eq(2)
    a[2]?.should be_nil
  end

  it "gets array of keys" do
    a = {} of Symbol => Int32
    a.keys.should eq([] of Symbol)
    a[:foo] = 1
    a[:bar] = 2
    a.keys.should eq([:foo, :bar])
  end

  it "gets array of values" do
    a = {} of Symbol => Int32
    a.values.should eq([] of Int32)
    a[:foo] = 1
    a[:bar] = 2
    a.values.should eq([1, 2])
  end

  describe "==" do
    assert do
      a = {1 => 2, 3 => 4}
      b = {3 => 4, 1 => 2}
      c = {2 => 3}
      d = {5 => 6, 7 => 8}
      a.should eq(a)
      a.should eq(b)
      b.should eq(a)
      a.should_not eq(c)
      c.should_not eq(a)
      d.should_not eq(a)
    end

    assert do
      a = {1 => nil}
      b = {3 => 4}
      a.should_not eq(b)
    end
  end

  describe "[]" do
    it "gets" do
      a = {1 => 2}
      a[1].should eq(2)
      # a[2].should raise_exception
      a.should eq({1 => 2})
    end
  end

  describe "[]=" do
    it "overrides value" do
      a = {1 => 2}
      a[1] = 3
      a[1].should eq(3)
    end
  end

  describe "fetch" do
    it "fetches with one argument" do
      a = {1 => 2}
      a.fetch(1).should eq(2)
      # a.fetch(2).should raise_exception
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
      a.fetch(1) { |k| k * 3 }.should eq(2)
      a.fetch(2) { |k| k * 3 }.should eq(6)
      a.should eq({1 => 2})
    end
  end

  describe "has_key?" do
    it "doesn't have key" do
      a = {1 => 2}
      a.has_key?(2).should be_false
    end

    it "has key" do
      a = {1 => 2}
      a.has_key?(1).should be_true
    end
  end

  describe "delete" do
    it "deletes key in the beginning" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.delete(1)
      a.length.should eq(2)
      a.should eq({3 => 4, 5 => 6})
    end

    it "deletes key in the middle" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.delete(3)
      a.length.should eq(2)
      a.should eq({1 => 2, 5 => 6})
    end

    it "deletes key in the end" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.delete(5)
      a.length.should eq(2)
      a.should eq({1 => 2, 3 =>4})
    end

    it "deletes only remaining entry" do
      a = {1 => 2}
      a.delete(1)
      a.length.should eq(0)
      a.should eq({} of Int32 => Int32)
    end
  end

  it "maps" do
    hash = {1 => 2, 3 => 4}
    array = hash.map { |k, v| k + v }
    array.should eq([3, 7])
  end

  describe "to_s" do
    assert { {1 => 2, 3 => 4}.to_s.should eq("{1 => 2, 3 => 4}") }
  end

  it "clones" do
    h1 = {1 => 2, 3 => 4}
    h2 = h1.clone
    h1.object_id.should_not eq(h2.object_id)
    h1.should eq(h2)
  end

  it "initializes with block" do
    h1 = Hash(String, Array(Int32)).new { |h, k| h[k] = [] of Int32 }
    h1["foo"].should eq([] of Int32)
    h1["bar"].push 2
    h1["bar"].should eq([2])
  end

  it "merges" do
    h1 = {1 => 2, 3 => 4}
    h2 = {1 => 5, 2 => 3}
    h3 = h1.merge(h2)
    h3.should eq({1 => 5, 3 => 4, 2 => 3})
  end

  it "zips" do
    ary1 = [1, 2, 3]
    ary2 = ['a', 'b', 'c']
    hash = Hash.zip(ary1, ary2)
    hash.should eq({1 => 'a', 2 => 'b', 3 => 'c'})
  end

  it "gets first key" do
    h = {1 => 2, 3 => 4}
    h.first_key.should eq(1)
  end

  it "gets first value" do
    h = {1 => 2, 3 => 4}
    h.first_value.should eq(2)
  end

  it "shifts" do
    h = {1 => 2, 3 => 4}
    e = h.shift
    e.key.should eq(1)
    e.value.should eq(2)
    h.should eq({3 => 4})
    e = h.shift
    e.key.should eq(3)
    e.value.should eq(4)
    h.empty?.should be_true
  end

  it "shifts?" do
    h = {1 => 2}
    e = h.shift?.not_nil!
    e.key.should eq(1)
    e.value.should eq(2)
    h.empty?.should be_true
    h.shift?.should be_nil
  end
end
