require "spec"

private alias RecursiveHash = Hash(RecursiveHash, RecursiveHash)

private class HashBreaker
  getter x : Int32

  def initialize(@x)
  end
end

private class NeverInstantiated
end

private alias RecursiveType = String | Int32 | Array(RecursiveType) | Hash(Symbol, RecursiveType)

describe "Hash" do
  describe "empty" do
    it "size should be zero" do
      h = {} of Int32 => Int32
      h.size.should eq(0)
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

  it "gets from union" do
    a = {1 => 2, :foo => 1.1}
    a[1].should eq(2)
  end

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
    it do
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

    it do
      a = {1 => nil}
      b = {3 => 4}
      a.should_not eq(b)
    end

    it "compares hash of nested hash" do
      a = { {1 => 2} => 3 }
      b = { {1 => 2} => 3 }
      a.should eq(b)
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

  describe "put" do
    it "puts in a small hash" do
      a = {} of Int32 => Int32
      a.put(1, 2) { nil }.should eq(nil)
      a.put(1, 3) { nil }.should eq(2)
    end

    it "puts in a big hash" do
      a = {} of Int32 => Int32
      100.times do |i|
        a[i] = i
      end
      a.put(100, 2) { nil }.should eq(nil)
      a.put(100, 3) { nil }.should eq(2)
    end

    it "yields key" do
      a = {} of Int32 => Int32
      a.put(1, 2, &.to_s).should eq("1")
    end
  end

  describe "dig?" do
    it "gets the value at given path given splat" do
      ary = [1, 2, 3]
      h = {"a" => {"b" => {"c" => [10, 20]}}, ary => {"a" => "b"}}

      h.dig?("a", "b", "c").should eq([10, 20])
      h.dig?(ary, "a").should eq("b")
    end

    it "returns nil if not found" do
      ary = [1, 2, 3]
      h = {"a" => {"b" => {"c" => 300}}, ary => {"a" => "b"}}

      h.dig?("a", "b", "c", "d", "e").should be_nil
      h.dig?("z").should be_nil
      h.dig?("").should be_nil
    end
  end

  describe "dig" do
    it "gets the value at given path given splat" do
      ary = [1, 2, 3]
      h = {"a" => {"b" => {"c" => [10, 20]}}, ary => {"a" => "b", "c" => nil}}

      h.dig("a", "b", "c").should eq([10, 20])
      h.dig(ary, "a").should eq("b")
      h.dig(ary, "c").should eq(nil)
    end

    it "raises KeyError if not found" do
      ary = [1, 2, 3]
      h = {"a" => {"b" => {"c" => 300}}, ary => {"a" => "b"}}

      expect_raises KeyError, %(Hash value not diggable for key: "c") do
        h.dig("a", "b", "c", "d", "e")
      end
      expect_raises KeyError, %(Missing hash key: "z") do
        h.dig("z")
      end
      expect_raises KeyError, %(Missing hash key: "") do
        h.dig("")
      end
    end
  end

  describe "fetch" do
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

  describe "values_at" do
    it "returns the given keys" do
      {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.values_at("b", "a", "c").should eq({2, 1, 3})
    end

    it "raises when passed an invalid key" do
      expect_raises KeyError do
        {"a" => 1}.values_at("b")
      end
    end

    it "works with mixed types" do
      {1 => :a, "a" => 1, 2.0 => "a", :a => 1.0}.values_at(1, "a", 2.0, :a).should eq({:a, 1, "a", 1.0})
    end
  end

  describe "key_for" do
    it "returns the first key with the given value" do
      hash = {"foo" => "bar", "baz" => "qux"}
      hash.key_for("bar").should eq("foo")
      hash.key_for("qux").should eq("baz")
    end

    it "raises when no key pairs with the given value" do
      expect_raises KeyError do
        {"foo" => "bar"}.key_for("qux")
      end
    end

    describe "if block is given," do
      it "returns the first key with the given value" do
        hash = {"foo" => "bar", "baz" => "bar"}
        hash.key_for("bar") { |value| value.upcase }.should eq("foo")
      end

      it "yields the argument if no hash key pairs with the value" do
        hash = {"foo" => "bar"}
        hash.key_for("qux") { |value| value.upcase }.should eq("QUX")
      end
    end
  end

  describe "key_for?" do
    it "returns the first key with the given value" do
      hash = {"foo" => "bar", "baz" => "qux"}
      hash.key_for?("bar").should eq("foo")
      hash.key_for?("qux").should eq("baz")
    end

    it "returns nil if no key pairs with the given value" do
      hash = {"foo" => "bar", "baz" => "qux"}
      hash.key_for?("foobar").should eq nil
      hash.key_for?("bazqux").should eq nil
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

  describe "has_value?" do
    it "returns true if contains the value" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.has_value?(4).should be_true
    end

    it "returns false if does not contain the value" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.has_value?(3).should be_false
    end
  end

  describe "delete" do
    it "deletes key in the beginning" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.delete(1).should eq(2)
      a.has_key?(1).should be_false
      a.has_key?(3).should be_true
      a.has_key?(5).should be_true
      a.size.should eq(2)
      a.should eq({3 => 4, 5 => 6})
    end

    it "deletes key in the middle" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.delete(3).should eq(4)
      a.has_key?(1).should be_true
      a.has_key?(3).should be_false
      a.has_key?(5).should be_true
      a.size.should eq(2)
      a.should eq({1 => 2, 5 => 6})
    end

    it "deletes key in the end" do
      a = {1 => 2, 3 => 4, 5 => 6}
      a.delete(5).should eq(6)
      a.has_key?(1).should be_true
      a.has_key?(3).should be_true
      a.has_key?(5).should be_false
      a.size.should eq(2)
      a.should eq({1 => 2, 3 => 4})
    end

    it "deletes only remaining entry" do
      a = {1 => 2}
      a.delete(1).should eq(2)
      a.has_key?(1).should be_false
      a.size.should eq(0)
      a.should eq({} of Int32 => Int32)
    end

    it "deletes not found" do
      a = {1 => 2}
      a.delete(2).should be_nil
    end

    it "deletes many in the beginning and then will need a resize" do
      h = {} of Int32 => Int32
      8.times do |i|
        h[i] = i
      end
      5.times do |i|
        h.delete(i)
      end
      (9..12).each do |i|
        h[i] = i
      end
      h.should eq({5 => 5, 6 => 6, 7 => 7, 9 => 9, 10 => 10, 11 => 11, 12 => 12})
    end

    describe "with block" do
      it "returns the value if a key is found" do
        a = {1 => 2}
        a.delete(1) { 5 }.should eq(2)
      end

      it "returns the value of the block if key is not found" do
        a = {1 => 2}
        a.delete(3) { |key| key }.should eq(3)
      end

      it "returns nil if key is found and value is nil" do
        {3 => nil}.delete(3) { 7 }.should be_nil
      end
    end
  end

  describe "size" do
    it "is the same as size" do
      a = {} of Int32 => Int32
      a.size.should eq(a.size)

      a = {1 => 2}
      a.size.should eq(a.size)

      a = {1 => 2, 3 => 4, 5 => 6, 7 => 8}
      a.size.should eq(a.size)
    end
  end

  it "maps" do
    hash = {1 => 2, 3 => 4}
    array = hash.map { |k, v| k + v }
    array.should eq([3, 7])
  end

  describe "to_s" do
    it { {1 => 2, 3 => 4}.to_s.should eq("{1 => 2, 3 => 4}") }

    it do
      h = {} of RecursiveHash => RecursiveHash
      h[h] = h
      h.to_s.should eq("{{...} => {...}}")
    end
  end

  it "does to_h" do
    h = {:a => 1}
    h.to_h.should be(h)
  end

  describe "clone" do
    it "clones with size = 1" do
      h1 = {1 => 2}
      h2 = h1.clone
      h1.should_not be(h2)
      h1.should eq(h2)
    end

    it "clones empty hash" do
      h1 = {} of Int32 => Int32
      h2 = h1.clone
      h2.empty?.should be_true
    end

    it "clones small hash" do
      h1 = {} of Int32 => Array(Int32)
      4.times do |i|
        h1[i] = [i]
      end
      h2 = h1.clone
      h1.should_not be(h2)
      h1.should eq(h2)

      4.times do |i|
        h1[i].should_not be(h2[i])
      end

      h1.delete(0)
      h2[0].should eq([0])
    end

    it "clones big hash" do
      h1 = {} of Int32 => Array(Int32)
      1_000.times do |i|
        h1[i] = [i]
      end
      h2 = h1.clone
      h1.should_not be(h2)
      h1.should eq(h2)

      1_000.times do |i|
        h1[i].should_not be(h2[i])
      end

      h1.delete(0)
      h2[0].should eq([0])
    end
  end

  describe "dup" do
    it "dups empty hash" do
      h1 = {} of Int32 => Int32
      h2 = h1.dup
      h2.empty?.should be_true
    end

    it "dups small hash" do
      h1 = {} of Int32 => Array(Int32)
      4.times do |i|
        h1[i] = [i]
      end
      h2 = h1.dup
      h1.should_not be(h2)
      h1.should eq(h2)

      4.times do |i|
        h1[i].should be(h2[i])
      end

      h1.delete(0)
      h2[0].should eq([0])
    end

    it "dups big hash" do
      h1 = {} of Int32 => Array(Int32)
      1_000.times do |i|
        h1[i] = [i]
      end
      h2 = h1.dup
      h1.should_not be(h2)
      h1.should eq(h2)

      1_000.times do |i|
        h1[i].should be(h2[i])
      end

      h1.delete(0)
      h2[0].should eq([0])
    end
  end

  it "initializes with block" do
    h1 = Hash(String, Array(Int32)).new { |h, k| h[k] = [] of Int32 }
    h1["foo"].should eq([] of Int32)
    h1["bar"].push 2
    h1["bar"].should eq([2])
  end

  it "initializes with default value" do
    h = Hash(Int32, Int32).new(10)
    h[0].should eq(10)
    h.has_key?(0).should be_false
    h[1] += 2
    h[1].should eq(12)
    h.has_key?(1).should be_true
  end

  it "merges" do
    h1 = {1 => 2, 3 => 4}
    h2 = {1 => 5, 2 => 3}
    h3 = {"1" => "5", "2" => "3"}

    h4 = h1.merge(h2)
    h4.should_not be(h1)
    h4.should eq({1 => 5, 3 => 4, 2 => 3})

    h5 = h1.merge(h3)
    h5.should_not be(h1)
    h5.should eq({1 => 2, 3 => 4, "1" => "5", "2" => "3"})
  end

  it "merges with block" do
    h1 = {1 => 5, 2 => 3}
    h2 = {1 => 5, 3 => 4, 2 => 3}

    h3 = h2.merge(h1) { |k, v1, v2| k + v1 + v2 }
    h3.should_not be(h2)
    h3.should eq({1 => 11, 3 => 4, 2 => 8})
  end

  it "merges recursive type (#1693)" do
    hash = {:foo => "bar"} of Symbol => RecursiveType
    result = hash.merge({:foobar => "foo"})
    result.should eq({:foo => "bar", :foobar => "foo"})
  end

  it "merges!" do
    h1 = {1 => 2, 3 => 4}
    h2 = {1 => 5, 2 => 3}

    h3 = h1.merge!(h2)
    h3.should be(h1)
    h3.should eq({1 => 5, 3 => 4, 2 => 3})
  end

  it "merges! with block" do
    h1 = {1 => 5, 2 => 3}
    h2 = {1 => 5, 3 => 4, 2 => 3}

    h3 = h2.merge!(h1) { |k, v1, v2| k + v1 + v2 }
    h3.should be(h2)
    h3.should eq({1 => 11, 3 => 4, 2 => 8})
  end

  it "merges! with block and nilable keys" do
    h1 = {1 => nil, 2 => 4, 3 => "x"}
    h2 = {1 => 2, 2 => nil, 3 => "y"}

    h3 = h1.merge!(h2) { |k, v1, v2| (v1 || v2).to_s }
    h3.should be(h1)
    h3.should eq({1 => "2", 2 => "4", 3 => "x"})
  end

  it "selects" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.select { |k, v| k == :b }
    h2.should eq({:b => 2})
    h2.should_not be(h1)
  end

  it "selects!" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.select! { |k, v| k == :b }
    h2.should eq({:b => 2})
    h2.should be(h1)
  end

  it "returns nil when using select! and no changes were made" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.select! { true }
    h2.should eq(nil)
    h1.should eq({:a => 1, :b => 2, :c => 3})
  end

  it "rejects" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.reject { |k, v| k == :b }
    h2.should eq({:a => 1, :c => 3})
    h2.should_not be(h1)
  end

  it "rejects!" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.reject! { |k, v| k == :b }
    h2.should eq({:a => 1, :c => 3})
    h2.should be(h1)
  end

  it "returns nil when using reject! and no changes were made" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.reject! { false }
    h2.should eq(nil)
    h1.should eq({:a => 1, :b => 2, :c => 3})
  end

  it "compacts" do
    h1 = {:a => 1, :b => 2, :c => nil}

    h2 = h1.compact
    h2.should be_a(Hash(Symbol, Int32))
    h2.should eq({:a => 1, :b => 2})
  end

  it "compacts!" do
    h1 = {:a => 1, :b => 2, :c => nil}

    h2 = h1.compact!
    h2.should eq({:a => 1, :b => 2})
    h2.should be(h1)
  end

  it "returns nil when using compact! and no changes were made" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.compact!
    h2.should be_nil
    h1.should eq({:a => 1, :b => 2, :c => 3})
  end

  it "transforms keys" do
    h1 = {1 => :a, 2 => :b, 3 => :c}

    h2 = h1.transform_keys { |x| x + 1 }
    h2.should eq({2 => :a, 3 => :b, 4 => :c})
  end

  it "transforms keys with type casting" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.transform_keys { |x| x.to_s.upcase }
    h2.should be_a(Hash(String, Int32))
    h2.should eq({"A" => 1, "B" => 2, "C" => 3})
  end

  it "returns empty hash when transforming keys of an empty hash" do
    h1 = {} of Int32 => Symbol

    h2 = h1.transform_keys { |x| x + 1 }
    h2.should be_a(Hash(Int32, Symbol))
    h2.empty?.should be_true
  end

  it "transforms values" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.transform_values { |x| x + 1 }
    h2.should eq({:a => 2, :b => 3, :c => 4})
  end

  it "transforms values with type casting values" do
    h1 = {:a => 1, :b => 2, :c => 3}

    h2 = h1.transform_values { |x| x.to_s }
    h2.should be_a(Hash(Symbol, String))
    h2.should eq({:a => "1", :b => "2", :c => "3"})
  end

  it "returns empty hash when transforming values of an empty hash" do
    h1 = {} of Symbol => Int32

    h2 = h1.transform_values { |x| x + 1 }
    h2.should be_a(Hash(Symbol, Int32))
    h2.empty?.should be_true
  end

  it "transform values in place" do
    h = {:a => 1, :b => 2, :c => 3}

    h.transform_values!(&.+(1))
    h.should eq({:a => 2, :b => 3, :c => 4})
  end

  it "zips" do
    ary1 = [1, 2, 3]
    ary2 = ['a', 'b', 'c']
    hash = Hash.zip(ary1, ary2)
    hash.should eq({1 => 'a', 2 => 'b', 3 => 'c'})
  end

  it "gets first" do
    h = {1 => 2, 3 => 4}
    h.first.should eq({1, 2})
  end

  describe "first_key" do
    it "gets first key" do
      h = {1 => 2, 3 => 4}
      h.first_key.should eq(1)
    end

    it "raises on first key (nilable key)" do
      h = {} of Int32? => Int32
      expect_raises(Exception, "Can't get first key of empty Hash") do
        h.first_key
      end
    end

    it "doesn't raise on first key (nilable key)" do
      h = {nil => 1} of Int32? => Int32
      h.first_key.should be_nil
    end
  end

  describe "first_value" do
    it "gets first value" do
      h = {1 => 2, 3 => 4}
      h.first_value.should eq(2)
    end

    it "raises on first value (nilable value)" do
      h = {} of Int32 => Int32?
      expect_raises(Exception, "Can't get first value of empty Hash") do
        h.first_value
      end
    end

    it "doesn't raise on first value (nilable value)" do
      h = {1 => nil} of Int32 => Int32?
      h.first_value.should be_nil
    end
  end

  describe "last_key" do
    it "gets last key" do
      h = {1 => 2, 3 => 4}
      h.last_key.should eq(3)
    end

    it "raises on last key (nilable key)" do
      h = {} of Int32? => Int32
      expect_raises(Exception, "Can't get last key of empty Hash") do
        h.last_key
      end
    end

    it "doesn't raise on last key (nilable key)" do
      h = {nil => 1} of Int32? => Int32
      h.last_key.should be_nil
    end
  end

  describe "last_value" do
    it "gets last value" do
      h = {1 => 2, 3 => 4}
      h.last_value.should eq(4)
    end

    it "raises on last value (nilable value)" do
      h = {} of Int32 => Int32?
      expect_raises(Exception, "Can't get last value of empty Hash") do
        h.last_value
      end
    end

    it "doesn't raise on last value (nilable value)" do
      h = {1 => nil} of Int32 => Int32?
      h.last_value.should be_nil
    end
  end

  it "shifts" do
    h = {1 => 2, 3 => 4}

    h.shift.should eq({1, 2})
    h.should eq({3 => 4})
    h.first_key.should eq(3)
    h.first_value.should eq(4)
    h[1]?.should be_nil
    h[3].should eq(4)

    h.each.to_a.should eq([{3, 4}])
    h.each_key.to_a.should eq([3])
    h.each_value.to_a.should eq([4])

    h.shift.should eq({3, 4})
    h.empty?.should be_true

    expect_raises(IndexError) do
      h.shift
    end

    20.times do |i|
      h[i] = i
    end
    h.size.should eq(20)

    20.times do |i|
      h.shift.should eq({i, i})
    end
    h.empty?.should be_true
  end

  it "shifts: delete elements in the middle position and then in the first position" do
    h = {1 => 'a', 2 => 'b', 3 => 'c', 4 => 'd'}
    h.delete(2)
    h.delete(3)
    h.delete(1)
    h.size.should eq(1)
    h.should eq({4 => 'd'})
    h.first.should eq({4, 'd'})
  end

  it "shifts?" do
    h = {1 => 2}
    h.shift?.should eq({1, 2})
    h.empty?.should be_true
    h.shift?.should be_nil
  end

  it "gets key index" do
    h = {1 => 2, 3 => 4}
    h.key_index(3).should eq(1)
    h.key_index(2).should be_nil
  end

  it "inserts many" do
    times = 1000
    h = {} of Int32 => Int32
    times.times do |i|
      h[i] = i
      h.size.should eq(i + 1)
    end
    times.times do |i|
      h[i].should eq(i)
    end
    h.first_key.should eq(0)
    h.first_value.should eq(0)
    times.times do |i|
      h.delete(i).should eq(i)
      h.has_key?(i).should be_false
      h.size.should eq(times - i - 1)
    end
  end

  it "inserts in one bucket and deletes from the same one" do
    h = {11 => 1}
    h.delete(0).should be_nil
    h.has_key?(11).should be_true
    h.size.should eq(1)
  end

  it "does to_a" do
    h = {1 => "hello", 2 => "bye"}
    h.to_a.should eq([{1, "hello"}, {2, "bye"}])
  end

  it "does to_a after shift" do
    h = {1 => 'a', 2 => 'b', 3 => 'c'}
    h.shift
    h.to_a.should eq([{2, 'b'}, {3, 'c'}])
  end

  it "does to_a after delete" do
    h = {1 => 'a', 2 => 'b', 3 => 'c'}
    h.delete(2)
    h.to_a.should eq([{1, 'a'}, {3, 'c'}])
  end

  it "clears" do
    h = {1 => 2, 3 => 4}
    h.clear
    h.empty?.should be_true
    h.to_a.size.should eq(0)
  end

  it "clears after shift" do
    h = {1 => 2, 3 => 4}
    h.shift
    h.clear
    h.empty?.should be_true
    h.to_a.size.should eq(0)
    h[5] = 6
    h.empty?.should be_false
    h[5].should eq(6)
    h.should eq({5 => 6})
  end

  it "computes hash" do
    h1 = { {1 => 2} => {3 => 4} }
    h2 = { {1 => 2} => {3 => 4} }
    h1.hash.should eq(h2.hash)

    h3 = {1 => 2, 3 => 4}
    h4 = {3 => 4, 1 => 2}

    h3.hash.should eq(h4.hash)
  end

  it "fetches from empty hash with default value" do
    x = {} of Int32 => HashBreaker
    breaker = x.fetch(10) { HashBreaker.new(1) }
    breaker.x.should eq(1)
  end

  it "does to to_s with instance that was never instantiated" do
    x = {} of Int32 => NeverInstantiated
    x.to_s.should eq("{}")
  end

  it "inverts" do
    h1 = {"one" => 1, "two" => 2, "three" => 3}
    h2 = {"a" => 1, "b" => 2, "c" => 1}

    h1.invert.should eq({1 => "one", 2 => "two", 3 => "three"})

    h3 = h2.invert
    h3.size.should eq(2)
    %w(a c).should contain h3[1]
  end

  it "does each" do
    hash = {"foo" => 1, "bar" => 2}
    ks = [] of String
    vs = [] of Int32
    hash.each do |k, v|
      ks << k
      vs << v
    end.should be_nil
    ks.should eq(["foo", "bar"])
    vs.should eq([1, 2])
  end

  it "does each_key" do
    hash = {"foo" => 1, "bar" => 2}
    ks = [] of String
    hash.each_key do |k|
      ks << k
    end.should be_nil
    ks.should eq(["foo", "bar"])
  end

  it "does each_value" do
    hash = {"foo" => 1, "bar" => 2}
    vs = [] of Int32
    hash.each_value do |v|
      vs << v
    end.should be_nil
    vs.should eq([1, 2])
  end

  it "gets each iterator" do
    iter = {:a => 1, :b => 2}.each
    iter.next.should eq({:a, 1})
    iter.next.should eq({:b, 2})
    iter.next.should be_a(Iterator::Stop)
  end

  it "gets each key iterator" do
    iter = {:a => 1, :b => 2}.each_key
    iter.next.should eq(:a)
    iter.next.should eq(:b)
    iter.next.should be_a(Iterator::Stop)
  end

  it "gets each value iterator" do
    iter = {:a => 1, :b => 2}.each_value
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should be_a(Iterator::Stop)
  end

  describe "each_with_index" do
    it "pass key, value, index values into block" do
      hash = {2 => 4, 5 => 10, 7 => 14}
      results = [] of Int32
      hash.each_with_index { |(k, v), i| results << k + v + i }.should be_nil
      results.should eq [6, 16, 23]
    end

    it "can be used with offset" do
      hash = {2 => 4, 5 => 10, 7 => 14}
      results = [] of Int32
      hash.each_with_index(3) { |(k, v), i| results << k + v + i }.should be_nil
      results.should eq [9, 19, 26]
    end
  end

  describe "each_with_object" do
    it "passes memo, key and value into block" do
      hash = {:a => 'b'}
      hash.each_with_object(:memo) do |(k, v), memo|
        memo.should eq(:memo)
        k.should eq(:a)
        v.should eq('b')
      end
    end

    it "reduces the hash to the accumulated value of memo" do
      hash = {:a => 'b', :c => 'd', :e => 'f'}
      result = nil
      result = hash.each_with_object({} of Char => Symbol) do |(k, v), memo|
        memo[v] = k
      end
      result.should eq({'b' => :a, 'd' => :c, 'f' => :e})
    end
  end

  describe "all?" do
    it "passes key and value into block" do
      hash = {:a => 'b'}
      hash.all? do |k, v|
        k.should eq(:a)
        v.should eq('b')
      end
    end

    it "returns true if the block evaluates truthy for every kv pair" do
      hash = {:a => 'b', :c => 'd'}
      result = hash.all? { |k, v| v < 'e' ? "truthy" : nil }
      result.should be_true
      hash[:d] = 'e'
      result = hash.all? { |k, v| v < 'e' ? "truthy" : nil }
      result.should be_false
    end

    it "evaluates the block for only for as many kv pairs as necessary" do
      hash = {:a => 'b', :c => 'd'}
      hash.all? do |k, v|
        raise Exception.new("continued iterating") if v == 'd'
        v == 'a' # this is false for the first kv pair
      end
    end
  end

  describe "any?" do
    it "passes key and value into block" do
      hash = {:a => 'b'}
      hash.any? do |k, v|
        k.should eq(:a)
        v.should eq('b')
      end
    end

    it "returns true if the block evaluates truthy for at least one kv pair" do
      hash = {:a => 'b', :c => 'd'}
      result = hash.any? { |k, v| v > 'b' ? "truthy" : nil }
      result.should be_true
      hash[:d] = 'e'
      result = hash.any? { |k, v| v > 'e' ? "truthy" : nil }
      result.should be_false
    end

    it "evaluates the block for only for as many kv pairs as necessary" do
      hash = {:a => 'b', :c => 'd'}
      hash.any? do |k, v|
        raise Exception.new("continued iterating") if v == 'd'
        v == 'b' # this is true for the first kv pair
      end
    end

    it "returns true if the hash contains at least one kv pair and no block is given" do
      hash = {:a => 'b'}
      result = hash.any?
      result.should be_true

      hash = {} of Symbol => Char
      result = hash.any?
      result.should be_false
    end
  end

  describe "reduce" do
    it "passes memo, key and value into block" do
      hash = {:a => 'b'}
      hash.reduce(:memo) do |memo, (k, v)|
        memo.should eq(:memo)
        k.should eq(:a)
        v.should eq('b')
      end
    end

    it "reduces the hash to the accumulated value of memo" do
      hash = {:a => 'b', :c => 'd', :e => 'f'}
      result = hash.reduce("") do |memo, (k, v)|
        memo + v
      end
      result.should eq("bdf")
    end
  end

  describe "reject" do
    it { {:a => 2, :b => 3}.reject(:b, :d).should eq({:a => 2}) }
    it { {:a => 2, :b => 3}.reject(:b, :a).should eq({} of Symbol => Int32) }
    it { {:a => 2, :b => 3}.reject([:b, :a]).should eq({} of Symbol => Int32) }
    it "does not change currrent hash" do
      h = {:a => 3, :b => 6, :c => 9}
      h2 = h.reject(:b, :c)
      h.should eq({:a => 3, :b => 6, :c => 9})
    end
  end

  describe "reject!" do
    it { {:a => 2, :b => 3}.reject!(:b, :d).should eq({:a => 2}) }
    it { {:a => 2, :b => 3}.reject!(:b, :a).should eq({} of Symbol => Int32) }
    it { {:a => 2, :b => 3}.reject!([:b, :a]).should eq({} of Symbol => Int32) }
    it "changes currrent hash" do
      h = {:a => 3, :b => 6, :c => 9}
      h.reject!(:b, :c)
      h.should eq({:a => 3})
    end
  end

  describe "select" do
    it { {:a => 2, :b => 3}.select(:b, :d).should eq({:b => 3}) }
    it { {:a => 2, :b => 3}.select.should eq({} of Symbol => Int32) }
    it { {:a => 2, :b => 3}.select(:b, :a).should eq({:a => 2, :b => 3}) }
    it { {:a => 2, :b => 3}.select([:b, :a]).should eq({:a => 2, :b => 3}) }
    it "does not change currrent hash" do
      h = {:a => 3, :b => 6, :c => 9}
      h2 = h.select(:b, :c)
      h.should eq({:a => 3, :b => 6, :c => 9})
    end
  end

  describe "select!" do
    it { {:a => 2, :b => 3}.select!(:b, :d).should eq({:b => 3}) }
    it { {:a => 2, :b => 3}.select!.should eq({} of Symbol => Int32) }
    it { {:a => 2, :b => 3}.select!(:b, :a).should eq({:a => 2, :b => 3}) }
    it { {:a => 2, :b => 3}.select!([:b, :a]).should eq({:a => 2, :b => 3}) }
    it "does change currrent hash" do
      h = {:a => 3, :b => 6, :c => 9}
      h.select!(:b, :c)
      h.should eq({:b => 6, :c => 9})
    end
  end

  it "doesn't generate a negative index for the bucket index (#2321)" do
    items = (0..100000).map { rand(100000).to_i16! }
    items.uniq.size
  end

  it "creates with initial capacity" do
    hash = Hash(Int32, Int32).new(initial_capacity: 1234)
    hash.@indices_size_pow2.should eq(12)
  end

  it "creates with initial capacity and default value" do
    hash = Hash(Int32, Int32).new(default_value: 3, initial_capacity: 1234)
    hash[1].should eq(3)
    hash.@indices_size_pow2.should eq(12)
  end

  it "creates with initial capacity and block" do
    hash = Hash(Int32, Int32).new(initial_capacity: 1234) { |h, k| h[k] = 3 }
    hash[1].should eq(3)
    hash.@indices_size_pow2.should eq(12)
  end

  it "rehashes" do
    a = [1]
    h = {a => 0}
    (10..100).each do |i|
      h[[i]] = i
    end
    a << 2
    h[a]?.should be_nil
    h.rehash
    h[a].should eq(0)
  end

  describe "some edge cases while changing the implementation to open addressing" do
    it "edge case 1" do
      h = {1 => 10}
      h[1]?.should eq(10)
      h.size.should eq(1)

      h.delete(1)
      h[1]?.should be_nil
      h.size.should eq(0)

      h[2] = 10
      h[2]?.should eq(10)
      h.size.should eq(1)

      h[2] = 10
      h[2]?.should eq(10)
      h.size.should eq(1)
    end

    it "edge case 2" do
      hash = Hash(Int32, Int32).new(initial_capacity: 0)
      hash.@indices_size_pow2.should eq(0)
      hash[1] = 2
      hash[1].should eq(2)
    end

    it "edge case 3" do
      h = {} of Int32 => Int32
      (1 << 17).times do |i|
        h[i] = i
        h[i].should eq(i)
      end
    end
  end

  describe "compare_by_identity" do
    it "small hash" do
      string = "foo"
      h = {string => 1}
      h.compare_by_identity?.should be_false
      h.compare_by_identity
      h.compare_by_identity?.should be_true
      h[string]?.should eq(1)
      h["fo" + "o"]?.should be_nil
    end

    it "big hash" do
      h = {} of String => Int32
      nums = (100..116).to_a
      strings = nums.map(&.to_s)
      strings.zip(nums) do |string, num|
        h[string] = num
      end
      h.compare_by_identity
      nums.each do |num|
        h[num.to_s]?.should be_nil
      end
      strings.zip(nums) do |string, num|
        h[string]?.should eq(num)
      end
    end

    it "retains compare_by_identity on dup" do
      h = ({} of String => Int32).compare_by_identity
      h.dup.compare_by_identity?.should be_true
    end

    it "retains compare_by_identity on clone" do
      h = ({} of String => Int32).compare_by_identity
      h.clone.compare_by_identity?.should be_true
    end
  end
end
