require "spec"

describe "NamedTuple" do
  it "does new" do
    NamedTuple.new(x: 1, y: 2).should eq({x: 1, y: 2})
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

    expect_raises(TypeCastError, /cast from String to Int32 failed/) do
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

    expect_raises(TypeCastError, /cast from String to Int32 failed/) do
      {foo: Int32, bar: Int32}.from({:foo => 1, :bar => "foo"})
    end
  end

  it "gets size" do
    {a: 1, b: 3}.size.should eq(2)
  end

  it "does [] with runtime key" do
    tup = {a: 1, b: 'a'}

    key = :a
    val = tup[key]
    val.should eq(1)
    typeof(val).should eq(Int32 | Char)

    key = :b
    val = tup[key]
    val.should eq('a')
    typeof(val).should eq(Int32 | Char)

    expect_raises(KeyError) do
      key = :c
      tup[key]
    end
  end

  it "does []? with runtime key" do
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

  it "does [] with string" do
    tup = {a: 1, b: 'a'}

    key = "a"
    val = tup[key]
    val.should eq(1)
    typeof(val).should eq(Int32 | Char)

    key = "b"
    val = tup[key]
    val.should eq('a')
    typeof(val).should eq(Int32 | Char)

    expect_raises(KeyError) do
      key = "c"
      tup[key]
    end
  end

  it "does []? with string" do
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
  end

  it "does to_a" do
    tup = {a: 1, b: 'a'}
    tup.to_a.should eq([{:a, 1}, {:b, 'a'}])
  end

  it "does key_index" do
    tup = {a: 1, b: 'a'}
    tup.to_a.should eq([{:a, 1}, {:b, 'a'}])
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

  it "does to_h" do
    tup1 = {a: 1, b: "hello"}
    hash = tup1.to_h
    hash.should eq({:a => 1, :b => "hello"})
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
  end

  it "does keys" do
    tup = {a: 1, b: 2}
    tup.keys.should eq({:a, :b})
  end

  it "does values" do
    tup = {a: 1, b: 'a'}
    tup.values.should eq({1, 'a'})
  end

  it "merges with other named tuple" do
    a = {one: 1, two: 2, three: 3, four: 4, five: 5, "im \"string": "works"}
    b = {two: "Two", three: true, "new one": "ok"}
    c = a.merge(b).merge(four: "Four").should eq({one: 1, two: "Two", three: true, four: "Four", five: 5, "new one": "ok", "im \"string": "works"})
  end

  it "does types" do
    tuple = {a: 1, b: 'a', c: "hello"}
    tuple.class.types.to_s.should eq("{a: Int32, b: Char, c: String}")
  end
end
