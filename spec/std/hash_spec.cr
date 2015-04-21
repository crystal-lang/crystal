require "spec"

alias RecursiveHash = Hash(RecursiveHash, RecursiveHash)

class HashBreaker
  getter x
  def initialize(@x)
  end
end

class NeverInstantiated
end

describe "Hash" do
  describe "empty" do
    it "length should be zero" do
      h = {} of Int32 => Int32
      expect(h.length).to eq(0)
      expect(h.empty?).to be_true
    end
  end

  it "sets and gets" do
    a = {} of Int32 => Int32
    a[1] = 2
    expect(a[1]).to eq(2)
  end

  it "gets from literal" do
    a = {1 => 2}
    expect(a[1]).to eq(2)
  end

  it "gets from union" do
    a = {1 => 2, :foo => 1.1}
    expect(a[1]).to eq(2)
  end

  it "gets nilable" do
    a = {1 => 2}
    expect(a[1]?).to eq(2)
    expect(a[2]?).to be_nil
  end

  it "gets array of keys" do
    a = {} of Symbol => Int32
    expect(a.keys).to eq([] of Symbol)
    a[:foo] = 1
    a[:bar] = 2
    expect(a.keys).to eq([:foo, :bar])
  end

  it "gets array of values" do
    a = {} of Symbol => Int32
    expect(a.values).to eq([] of Int32)
    a[:foo] = 1
    a[:bar] = 2
    expect(a.values).to eq([1, 2])
  end

  describe "==" do
    assert do
      a = {1 => 2, 3 => 4}
      b = {3 => 4, 1 => 2}
      c = {2 => 3}
      d = {5 => 6, 7 => 8}
      expect(a).to eq(a)
      expect(a).to eq(b)
      expect(b).to eq(a)
      expect(a).to_not eq(c)
      expect(c).to_not eq(a)
      expect(d).to_not eq(a)
    end

    assert do
      a = {1 => nil}
      b = {3 => 4}
      expect(a).to_not eq(b)
    end

    it "compares hash of nested hash" do
      a = { {1 => 2} => 3}
      b = { {1 => 2} => 3}
      expect(a).to eq(b)
    end
  end

  describe "[]" do
    it "gets" do
      a = {1 => 2}
      expect(a[1]).to eq(2)
      expect(# a[2]).to raise_exception
      expect(a).to eq({1 => 2})
    end
  end

  describe "[]=" do
    it "overrides value" do
      a = {1 => 2}
      a[1] = 3
      expect(a[1]).to eq(3)
    end
  end

  describe "fetch" do
    it "fetches with one argument" do
      a = {1 => 2}
      expect(a.fetch(1)).to eq(2)
      expect(a).to eq({1 => 2})
    end

    it "fetches with default value" do
      a = {1 => 2}
      expect(a.fetch(1, 3)).to eq(2)
      expect(a.fetch(2, 3)).to eq(3)
      expect(a).to eq({1 => 2})
    end

    it "fetches with block" do
      a = {1 => 2}
      expect(a.fetch(1) { |k| k * 3 }).to eq(2)
      expect(a.fetch(2) { |k| k * 3 }).to eq(6)
      expect(a).to eq({1 => 2})
    end

    it "fetches and raises" do
      a = {1 => 2}
      expect_raises MissingKey, "Missing hash value: 2" do
        a.fetch(2)
      end
    end
  end

  describe "has_key?" do
    it "doesn't have key" do
      a = {1 => 2}
      expect(a.has_key?(2)).to be_false
    end

    it "has key" do
      a = {1 => 2}
      expect(a.has_key?(1)).to be_true
    end
  end

  describe "delete" do
    it "deletes key in the beginning" do
      a = {1 => 2, 3 => 4, 5 => 6}
      expect(a.delete(1)).to eq(2)
      expect(a.has_key?(1)).to be_false
      expect(a.has_key?(3)).to be_true
      expect(a.has_key?(5)).to be_true
      expect(a.length).to eq(2)
      expect(a).to eq({3 => 4, 5 => 6})
    end

    it "deletes key in the middle" do
      a = {1 => 2, 3 => 4, 5 => 6}
      expect(a.delete(3)).to eq(4)
      expect(a.has_key?(1)).to be_true
      expect(a.has_key?(3)).to be_false
      expect(a.has_key?(5)).to be_true
      expect(a.length).to eq(2)
      expect(a).to eq({1 => 2, 5 => 6})
    end

    it "deletes key in the end" do
      a = {1 => 2, 3 => 4, 5 => 6}
      expect(a.delete(5)).to eq(6)
      expect(a.has_key?(1)).to be_true
      expect(a.has_key?(3)).to be_true
      expect(a.has_key?(5)).to be_false
      expect(a.length).to eq(2)
      expect(a).to eq({1 => 2, 3 =>4})
    end

    it "deletes only remaining entry" do
      a = {1 => 2}
      expect(a.delete(1)).to eq(2)
      expect(a.has_key?(1)).to be_false
      expect(a.length).to eq(0)
      expect(a).to eq({} of Int32 => Int32)
    end

    it "deletes not found" do
      a = {1 => 2}
      expect(a.delete(2)).to be_nil
    end
  end

  it "maps" do
    hash = {1 => 2, 3 => 4}
    array = hash.map { |k, v| k + v }
    expect(array).to eq([3, 7])
  end

  describe "to_s" do
    assert { expect({1 => 2, 3 => 4}.to_s).to eq("{1 => 2, 3 => 4}") }

    assert do
      h = {} of RecursiveHash => RecursiveHash
      h[h] = h
      expect(h.to_s).to eq("{{...} => {...}}")
    end
  end

  it "does to_h" do
    h = {a: 1}
    expect(h.to_h).to be(h)
  end

  it "clones" do
    h1 = {1 => 2, 3 => 4}
    h2 = h1.clone
    expect(h1.object_id).to_not eq(h2.object_id)
    expect(h1).to eq(h2)
  end

  it "initializes with block" do
    h1 = Hash(String, Array(Int32)).new { |h, k| h[k] = [] of Int32 }
    expect(h1["foo"]).to eq([] of Int32)
    h1["bar"].push 2
    expect(h1["bar"]).to eq([2])
  end

  it "initializes with default value" do
    h = Hash(Int32, Int32).new(10)
    expect(h[0]).to eq(10)
    expect(h.has_key?(0)).to be_false
    h[1] += 2
    expect(h[1]).to eq(12)
    expect(h.has_key?(1)).to be_true
  end

  it "initializes with comparator" do
    h = Hash(String, Int32).new(Hash::CaseInsensitiveComparator)
    h["foo"] = 1
    expect(h["foo"]).to eq(1)
    expect(h["FoO"]).to eq(1)
  end

  it "initializes with block and comparator" do
    h1 = Hash(String, Array(Int32)).new(Hash::CaseInsensitiveComparator) { |h, k| h[k] = [] of Int32 }
    expect(h1["foo"]).to eq([] of Int32)
    h1["bar"] = [2]
    expect(h1["BAR"]).to eq([2])
  end

  it "initializes with default value and comparator" do
    h = Hash(String, Int32).new(10, Hash::CaseInsensitiveComparator)
    expect(h["x"]).to eq(10)
    expect(h.has_key?("x")).to be_false
    h["foo"] = 5
    expect(h["FoO"]).to eq(5)
  end

  it "merges" do
    h1 = {1 => 2, 3 => 4}
    h2 = {1 => 5, 2 => 3}
    h3 = h1.merge(h2)
    expect(h3.object_id).to_not eq(h1.object_id)
    expect(h3).to eq({1 => 5, 3 => 4, 2 => 3})
  end

  it "merges!" do
    h1 = {1 => 2, 3 => 4}
    h2 = {1 => 5, 2 => 3}
    h3 = h1.merge!(h2)
    expect(h3.object_id).to eq(h1.object_id)
    expect(h3).to eq({1 => 5, 3 => 4, 2 => 3})
  end

  it "zips" do
    ary1 = [1, 2, 3]
    ary2 = ['a', 'b', 'c']
    hash = Hash.zip(ary1, ary2)
    expect(hash).to eq({1 => 'a', 2 => 'b', 3 => 'c'})
  end

  it "gets first" do
    h = {1 => 2, 3 => 4}
    expect(h.first).to eq({1, 2})
  end

  it "gets first key" do
    h = {1 => 2, 3 => 4}
    expect(h.first_key).to eq(1)
  end

  it "gets first value" do
    h = {1 => 2, 3 => 4}
    expect(h.first_value).to eq(2)
  end

  it "shifts" do
    h = {1 => 2, 3 => 4}
    expect(h.shift).to eq({1, 2})
    expect(h).to eq({3 => 4})
    expect(h.shift).to eq({3, 4})
    expect(h.empty?).to be_true
  end

  it "shifts?" do
    h = {1 => 2}
    expect(h.shift?).to eq({1, 2})
    expect(h.empty?).to be_true
    expect(h.shift?).to be_nil
  end

  it "works with custom comparator" do
    h = Hash(String, Int32).new(Hash::CaseInsensitiveComparator)
    h["FOO"] = 1
    expect(h["foo"]).to eq(1)
    expect(h["Foo"]).to eq(1)
  end

  it "gets key index" do
    h = {1 => 2, 3 => 4}
    expect(h.key_index(3)).to eq(1)
    expect(h.key_index(2)).to be_nil
  end

  it "inserts many" do
    times = 1000
    h = {} of Int32 => Int32
    times.times do |i|
      h[i] = i
      expect(h.length).to eq(i + 1)
    end
    times.times do |i|
      expect(h[i]).to eq(i)
    end
    expect(h.first_key).to eq(0)
    expect(h.first_value).to eq(0)
    times.times do |i|
      expect(h.delete(i)).to eq(i)
      expect(h.has_key?(i)).to be_false
      expect(h.length).to eq(times - i - 1)
    end
  end

  it "inserts in one bucket and deletes from the same one" do
    h = {11 => 1}
    expect(h.delete(0)).to be_nil
    expect(h.has_key?(11)).to be_true
    expect(h.length).to eq(1)
  end

  it "does to_a" do
    h = {1 => "hello", 2 => "bye"}
    expect(h.to_a).to eq([{1, "hello"}, {2, "bye"}])
  end

  it "clears" do
    h = {1 => 2, 3 => 4}
    h.clear
    expect(h.empty?).to be_true
    expect(h.to_a.length).to eq(0)
  end

  it "computes hash" do
    h = { {1 => 2} => {3 => 4} }
    expect(h.hash).to_not eq(h.object_id)

    h2 = { {1 => 2} => {3 => 4} }
    expect(h.hash).to eq(h2.hash)
  end

  it "fetches from empty hash with default value" do
    x = {} of Int32 => HashBreaker
    breaker = x.fetch(10) { HashBreaker.new(1) }
    expect(breaker.x).to eq(1)
  end

  it "does to to_s with instance that was never instantiated" do
    x = {} of Int32 => NeverInstantiated
    expect(x.to_s).to eq("{}")
  end

  it "deletes if" do
    x = {a: 1, b: 2, c: 3, d: 4}
    x.delete_if { |k, v| v % 2 == 0 }
    expect(x).to eq({a: 1, c: 3})
  end
end
