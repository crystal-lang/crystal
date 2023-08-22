require "spec"

private record NamedTupleSpecObj, x : Int32 do
  def_equals @x
end

describe "NamedTuple" do
  it "does NamedTuple.new, without type vars" do
    NamedTuple.new(x: 1, y: 2).should eq({x: 1, y: 2})
    NamedTuple.new(z: NamedTupleSpecObj.new(10)).should eq({z: NamedTupleSpecObj.new(10)})
  end

  it "does NamedTuple.new, with type vars" do
    NamedTuple(foo: Int32, bar: String).new(foo: 1, bar: "a").should eq({foo: 1, bar: "a"})
    NamedTuple(z: NamedTupleSpecObj).new(z: NamedTupleSpecObj.new(10)).should eq({z: NamedTupleSpecObj.new(10)})
    typeof(NamedTuple.new).new.should eq(NamedTuple.new)

    t = NamedTuple(foo: Int32 | String, bar: Int32 | String).new(foo: 1, bar: "a")
    t.should eq({foo: 1, bar: "a"})
    t.class.should_not eq(NamedTuple(foo: Int32, bar: String))
  end

  it "does NamedTuple.from" do
    t = NamedTuple(foo: Int32, bar: Int32).from({:foo => 1, :bar => 2})
    t.should eq({foo: 1, bar: 2})
    t.class.should eq(NamedTuple(foo: Int32, bar: Int32))

    t = NamedTuple(foo: Int32, bar: Int32).from({"foo" => 1, "bar" => 2})
    t.should eq({foo: 1, bar: 2})
    t.class.should eq(NamedTuple(foo: Int32, bar: Int32))

    t = NamedTuple("foo bar": Int32, "baz qux": Int32).from({"foo bar" => 1, "baz qux" => 2})
    t.should eq({"foo bar": 1, "baz qux": 2})
    t.class.should eq(NamedTuple("foo bar": Int32, "baz qux": Int32))

    expect_raises ArgumentError do
      NamedTuple(foo: Int32, bar: Int32).from({:foo => 1})
    end

    expect_raises KeyError do
      NamedTuple(foo: Int32, bar: Int32).from({:foo => 1, :baz => 2})
    end

    expect_raises(TypeCastError, /[Cc]ast from String to Int32 failed/) do
      NamedTuple(foo: Int32, bar: Int32).from({:foo => 1, :bar => "foo"})
    end
  end

  it "does NamedTuple#from" do
    t = {foo: Int32, bar: Int32}.from({:foo => 1, :bar => 2})
    t.should eq({foo: 1, bar: 2})
    t.class.should eq(NamedTuple(foo: Int32, bar: Int32))

    t = {foo: Int32, bar: Int32}.from({"foo" => 1, "bar" => 2})
    t.should eq({foo: 1, bar: 2})
    t.class.should eq(NamedTuple(foo: Int32, bar: Int32))

    expect_raises ArgumentError do
      {foo: Int32, bar: Int32}.from({:foo => 1})
    end

    expect_raises KeyError do
      {foo: Int32, bar: Int32}.from({:foo => 1, :baz => 2})
    end

    expect_raises(TypeCastError, /[Cc]ast from String to Int32 failed/) do
      {foo: Int32, bar: Int32}.from({:foo => 1, :bar => "foo"})
    end

    t = {foo: Int32, bar: Int32}.from({"foo" => 1, :bar => 2})
    t.should eq({foo: 1, bar: 2})
    t.class.should eq(NamedTuple(foo: Int32, bar: Int32))

    t = {foo: Int32, bar: Int32}.from({"foo" => 1, :bar => 2} of String | Int32 | Symbol => Int32)
    t.should eq({foo: 1, bar: 2})
    t.class.should eq(NamedTuple(foo: Int32, bar: Int32))
  end

  it "gets size" do
    {a: 1, b: 3}.size.should eq(2)
  end

  describe "#[] with non-literal index" do
    it "gets named tuple value with Symbol key" do
      tup = {a: 1, b: 'a'}

      key = :a
      val = tup[key]
      val.should eq(1)
      typeof(val).should eq(Int32 | Char)

      key = :b
      val = tup[key]
      val.should eq('a')
      typeof(val).should eq(Int32 | Char)
    end

    it "gets named tuple value with String key" do
      tup = {a: 1, b: 'a'}

      key = "a"
      val = tup[key]
      val.should eq(1)
      typeof(val).should eq(Int32 | Char)

      key = "b"
      val = tup[key]
      val.should eq('a')
      typeof(val).should eq(Int32 | Char)
    end

    it "raises missing key" do
      tup = {a: 1, b: 'a'}
      key = :c
      expect_raises(KeyError) { tup[key] }
      key = "d"
      expect_raises(KeyError) { tup[key] }
    end
  end

  describe "#[]? with non-literal index" do
    it "gets named tuple value or nil with Symbol key" do
      tup = {a: 1, b: 'a'}

      key = :a
      val = tup[key]?
      val.should eq(1)
      typeof(val).should eq(Int32 | Char | Nil)

      key = :b
      val = tup[key]?
      val.should eq('a')
      typeof(val).should eq(Int32 | Char | Nil)

      key = :c
      val = tup[key]?
      val.should be_nil
      typeof(val).should eq(Int32 | Char | Nil)
    end

    it "gets named tuple value or nil with String key" do
      tup = {a: 1, b: 'a'}

      key = "a"
      val = tup[key]?
      val.should eq(1)
      typeof(val).should eq(Int32 | Char | Nil)

      key = "b"
      val = tup[key]?
      val.should eq('a')
      typeof(val).should eq(Int32 | Char | Nil)

      key = "c"
      val = tup[key]?
      val.should be_nil
      typeof(val).should eq(Int32 | Char | Nil)
    end
  end

  describe ".[] with non-literal index" do
    it "gets named tuple metaclass value with Symbol key" do
      tup = NamedTuple(a: Int32, b: Char)

      key = :a
      val = tup[key]
      val.should eq(Int32)
      typeof(val).should eq(Union(Int32.class, Char.class))

      key = :b
      val = tup[key]
      val.should eq(Char)
      typeof(val).should eq(Union(Int32.class, Char.class))
    end

    it "gets named tuple metaclass value with String key" do
      tup = NamedTuple(a: Int32, b: Char)

      key = "a"
      val = tup[key]
      val.should eq(Int32)
      typeof(val).should eq(Union(Int32.class, Char.class))

      key = "b"
      val = tup[key]
      val.should eq(Char)
      typeof(val).should eq(Union(Int32.class, Char.class))
    end

    it "raises missing key" do
      tup = NamedTuple(a: Int32, b: Char)
      key = :c
      expect_raises(KeyError) { tup[key] }
      key = "d"
      expect_raises(KeyError) { tup[key] }
    end
  end

  describe ".[]? with non-literal index" do
    it "gets named tuple metaclass value or nil with Symbol key" do
      tup = NamedTuple(a: Int32, b: Char)

      key = :a
      val = tup[key]?
      val.should eq(Int32)
      typeof(val).should eq(Union(Int32.class, Char.class, Nil))

      key = :b
      val = tup[key]?
      val.should eq(Char)
      typeof(val).should eq(Union(Int32.class, Char.class, Nil))

      key = :c
      val = tup[key]?
      val.should be_nil
      typeof(val).should eq(Union(Int32.class, Char.class, Nil))
    end

    it "gets named tuple metaclass value or nil with String key" do
      tup = NamedTuple(a: Int32, b: Char)

      key = "a"
      val = tup[key]?
      val.should eq(Int32)
      typeof(val).should eq(Union(Int32.class, Char.class, Nil))

      key = "b"
      val = tup[key]?
      val.should eq(Char)
      typeof(val).should eq(Union(Int32.class, Char.class, Nil))

      key = "c"
      val = tup[key]?
      val.should be_nil
      typeof(val).should eq(Union(Int32.class, Char.class, Nil))
    end
  end

  describe "#dig?" do
    it "gets the value at given path given splat" do
      h = {a: {b: {c: [10, 20]}}, x: {a: "b"}}

      h.dig?(:a, :b, :c).should eq([10, 20])
      h.dig?("x", "a").should eq("b")
    end

    it "returns nil if not found" do
      h = {a: {b: {c: 300}}, x: {a: "b"}}

      h.dig?("a", "b", "c", "d", "e").should be_nil
      h.dig?("z").should be_nil
      h.dig?("").should be_nil
    end
  end

  describe "#dig" do
    it "gets the value at given path given splat" do
      h = {a: {b: {c: [10, 20]}}, x: {a: "b", c: nil}}

      h.dig(:a, :b, :c).should eq([10, 20])
      h.dig("x", "a").should eq("b")
      h.dig("x", "c").should eq(nil)
    end

    it "raises KeyError if not found" do
      h = {a: {b: {c: 300}}, x: {a: "b"}}

      expect_raises KeyError, %(NamedTuple value not diggable for key: "c") do
        h.dig("a", "b", "c", "d", "e")
      end
      expect_raises KeyError, %(Missing named tuple key: "z") do
        h.dig("z")
      end
      expect_raises KeyError, %(Missing named tuple key: "") do
        h.dig("")
      end
    end
  end

  it "computes a hash value" do
    tup1 = {a: 1, b: 'a'}
    tup1.hash.should eq(tup1.dup.hash)

    tup2 = {b: 'a', a: 1}
    tup2.hash.should eq(tup1.hash)
  end

  it "does each" do
    tup = {a: 1, b: "hello"}
    i = 0
    tup.each do |key, value|
      case i
      when 0
        key.should eq(:a)
        value.should eq(1)
      when 1
        key.should eq(:b)
        value.should eq("hello")
      else
        fail "shouldn't happen"
      end
      i += 1
    end.should be_nil
    i.should eq(2)
  end

  it "does each_key" do
    tup = {a: 1, b: "hello"}
    i = 0
    tup.each_key do |key|
      case i
      when 0
        key.should eq(:a)
      when 1
        key.should eq(:b)
      else
        fail "shouldn't happen"
      end
      i += 1
    end.should be_nil
    i.should eq(2)
  end

  it "does each_value" do
    tup = {a: 1, b: "hello"}
    i = 0
    tup.each_value do |value|
      case i
      when 0
        value.should eq(1)
      when 1
        value.should eq("hello")
      else
        fail "shouldn't happen"
      end
      i += 1
    end.should be_nil
    i.should eq(2)
  end

  it "does each_with_index" do
    tup = {a: 1, b: "hello"}
    i = 0
    tup.each_with_index do |key, value, index|
      case i
      when 0
        key.should eq(:a)
        value.should eq(1)
        index.should eq(0)
      when 1
        key.should eq(:b)
        value.should eq("hello")
        index.should eq(1)
      else
        fail "shouldn't happen"
      end
      i += 1
    end.should be_nil
    i.should eq(2)
  end

  it "does has_key? with symbol" do
    tup = {a: 1, b: 'a'}
    tup.has_key?(:a).should be_true
    tup.has_key?(:b).should be_true
    tup.has_key?(:c).should be_false
  end

  it "does has_key? with string" do
    tup = {a: 1, b: 'a'}
    tup.has_key?("a").should be_true
    tup.has_key?("b").should be_true
    tup.has_key?("c").should be_false
  end

  it "does empty" do
    {a: 1}.empty?.should be_false
    NamedTuple.new.empty?.should be_true
  end

  describe "#to_a" do
    it "creates an array of key-value pairs" do
      tup = {a: 1, b: 'a'}
      tup.to_a.should eq([{:a, 1}, {:b, 'a'}])
    end

    it "preserves key type for empty named tuples" do
      tup = NamedTuple.new
      arr = tup.to_a
      arr.should be_empty
      arr.should be_a(Array({Symbol, NoReturn}))
    end
  end

  it "does map" do
    tup = {a: 1, b: 'a'}
    strings = tup.map { |k, v| "#{k.inspect}-#{v.inspect}" }
    strings.should eq([":a-1", ":b-'a'"])
  end

  it "compares with same named tuple type" do
    tup1 = {a: 1, b: 'a'}
    tup2 = {b: 'a', a: 1}
    tup3 = {a: 1, b: 'b'}
    tup1.should eq(tup2)
    tup1.should_not eq(tup3)
  end

  it "compares with other named tuple type" do
    tup1 = {a: 1, b: 'a'}
    tup2 = {b: 'a', a: 1.0}
    tup3 = {b: 'a', a: 1.1}
    tup1.should eq(tup2)
    tup1.should_not eq(tup3)
  end

  it "compares with named tuple union (#5131)" do
    tup1 = {a: 1, b: 'a'}
    tup2 = {a: 1, c: 'b'}
    u = tup1 || tup2
    u.should eq(u)

    v = tup2 || tup1
    u.should_not eq(v)
  end

  describe "#to_h" do
    it "creates a hash" do
      tup1 = {a: 1, b: "hello"}
      hash = tup1.to_h
      hash.should eq({:a => 1, :b => "hello"})
    end

    it "creates an empty hash from an empty named tuple" do
      tup = NamedTuple.new
      hash = tup.to_h
      hash.should be_empty
      hash.should be_a(Hash(Symbol, NoReturn))
    end
  end

  it "does to_s" do
    tup = {a: 1, b: "hello"}
    tup.to_s.should eq(%({a: 1, b: "hello"}))
  end

  it "dups" do
    tup1 = {a: 1, b: [1, 2, 3]}
    tup2 = tup1.dup

    tup1[:b] << 4
    tup2[:b].should be(tup1[:b])
  end

  it "clones" do
    tup1 = {a: 1, b: [1, 2, 3]}
    tup2 = tup1.clone

    tup1[:b] << 4
    tup2[:b].should eq([1, 2, 3])

    tup2 = {"foo bar": 1}
    tup2.clone.should eq(tup2)

    tup3 = NamedTuple.new
    tup3.clone.should eq(tup3)
  end

  it "does keys" do
    tup = {a: 1, b: 2}
    tup.keys.should eq({:a, :b})
  end

  it "does sorted_keys" do
    tup = {foo: 1, bar: 2, baz: 3}
    tup.sorted_keys.should eq({:bar, :baz, :foo})
  end

  it "does values" do
    tup = {a: 1, b: 'a'}
    tup.values.should eq({1, 'a'})
  end

  it "merges with other named tuple" do
    a = {one: 1, two: 2, three: 3, four: 4, five: 5, "im \"string": "works"}
    b = {two: "Two", three: true, "new one": "ok"}
    a.merge(b).merge(four: "Four").merge(NamedTuple.new).should eq({one: 1, two: "Two", three: true, four: "Four", five: 5, "new one": "ok", "im \"string": "works"})
  end

  it "merges two empty named tuples" do
    NamedTuple.new.merge(NamedTuple.new).should eq(NamedTuple.new)
  end

  it "does types" do
    tuple = {a: 1, b: 'a', c: "hello"}
    tuple.class.types.to_s.should eq("{a: Int32, b: Char, c: String}")
  end
end
