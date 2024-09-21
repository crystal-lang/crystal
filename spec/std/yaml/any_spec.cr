require "spec"
require "yaml"
require "json"

private def it_fetches_from_hash(key, *equivalent_keys)
  it "fetches #{key.class}" do
    any = YAML::Any.new({YAML::Any.new(key) => YAML::Any.new("bar")})

    any[key].raw.should eq("bar")
    any[YAML::Any.new(key)].raw.should eq("bar")

    equivalent_keys.each do |k|
      any[k].raw.should eq("bar")
      # FIXME: Can't do `YAML::Any.new` with arbitrary number types (#11645)
      if k.is_a?(YAML::Any::Type)
        any[YAML::Any.new(k)].raw.should eq("bar")
      end
    end

    unless key.nil?
      expect_raises(KeyError, %(Missing hash key: nil)) do
        any[nil]
      end

      expect_raises(KeyError, %(Missing hash key: nil)) do
        any[YAML::Any.new(nil)]
      end
    end

    expect_raises(KeyError, %(Missing hash key: "fox")) do
      any["fox"]
    end

    expect_raises(KeyError, %(Missing hash key: "fox")) do
      any[YAML::Any.new("fox")]
    end

    expect_raises(KeyError, %(Missing hash key: 2)) do
      any[2]
    end

    expect_raises(KeyError, %(Missing hash key: 2)) do
      any[YAML::Any.new(2i64)]
    end

    expect_raises(KeyError, %(Missing hash key: 2)) do
      any[2.0]
    end

    expect_raises(KeyError, %(Missing hash key: 2)) do
      any[YAML::Any.new(2.0f64)]
    end

    expect_raises(KeyError, %(Missing hash key: 'c')) do
      any['c']
    end
  end
end

private def it_fetches_from_hash?(key, *equivalent_keys)
  it "fetches #{key.class}" do
    any = YAML::Any.new({YAML::Any.new(key) => YAML::Any.new("bar")})

    any[key]?.try(&.raw).should eq("bar")
    any[YAML::Any.new(key)]?.try(&.raw).should eq("bar")

    equivalent_keys.each do |k|
      any[k]?.try(&.raw).should eq("bar")
      # FIXME: Can't do `YAML::Any.new` with arbitrary number types (#11645)
      if k.is_a?(YAML::Any::Type)
        any[YAML::Any.new(k)]?.try(&.raw).should eq("bar")
      end
    end

    unless key.nil?
      any[nil]?.should be_nil
      any[YAML::Any.new(nil)]?.should be_nil
    end

    any["fox"]?.should be_nil
    any[YAML::Any.new("fox")]?.should be_nil
    any[2]?.should be_nil
    any[YAML::Any.new(2i64)]?.should be_nil
    any[2.0]?.should be_nil
    any[YAML::Any.new(2.0f64)]?.should be_nil

    any['c']?.should be_nil
  end
end

describe YAML::Any do
  it ".new" do
    YAML::Any.new(nil).raw.should be_nil
    YAML::Any.new(true).raw.should eq true
    YAML::Any.new(1_i64).raw.should eq 1_i64
    YAML::Any.new(1).raw.should eq 1
    YAML::Any.new(1_u8).raw.should eq 1
    YAML::Any.new(0.0).raw.should eq 0.0
    YAML::Any.new(0.0_f32).raw.should eq 0.0
    YAML::Any.new("foo").raw.should eq "foo"
    YAML::Any.new(Time.utc(2023, 7, 2)).raw.should eq Time.utc(2023, 7, 2)
    YAML::Any.new(Bytes[1, 2, 3]).raw.should eq Bytes[1, 2, 3]
    YAML::Any.new([] of YAML::Any).raw.should eq [] of YAML::Any
    YAML::Any.new({} of YAML::Any => YAML::Any).raw.should eq({} of YAML::Any => YAML::Any)
    YAML::Any.new(Set(YAML::Any).new).raw.should eq Set(YAML::Any).new
  end

  describe "casts" do
    it "gets nil" do
      YAML.parse("").as_nil.should be_nil
    end

    it "gets bool" do
      YAML.parse("true").as_bool.should be_true
      YAML.parse("false").as_bool.should be_false
      YAML.parse("true").as_bool?.should be_true
      YAML.parse("false").as_bool?.should be_false
      YAML.parse("2").as_bool?.should be_nil
    end

    it "gets string" do
      YAML.parse("hello").as_s.should eq("hello")
      YAML.parse("hello").as_s?.should eq("hello")
      YAML.parse("hello:\n- cruel\n- world\n").as_s?.should be_nil
    end

    it "gets array" do
      YAML.parse("- foo\n- bar\n").as_a.should eq(["foo", "bar"])
      YAML.parse("- foo\n- bar\n").as_a?.should eq(["foo", "bar"])
      YAML.parse("hello").as_a?.should be_nil
    end

    it "gets hash" do
      YAML.parse("foo: bar").as_h.should eq({"foo" => "bar"})
      YAML.parse("foo: bar").as_h?.should eq({"foo" => "bar"})
      YAML.parse("foo: bar")["foo"].as_h?.should be_nil
    end

    it "gets int32" do
      value = YAML.parse("1").as_i
      value.should eq(1)
      value.should be_a(Int32)

      value = YAML.parse("1").as_i?
      value.should eq(1)
      value.should be_a(Int32)

      value = YAML.parse("true").as_i?
      value.should be_nil
    end

    it "gets int64" do
      value = YAML.parse("1").as_i64
      value.should eq(1)
      value.should be_a(Int64)

      value = YAML.parse("1").as_i64?
      value.should eq(1)
      value.should be_a(Int64)

      value = YAML.parse("true").as_i64?
      value.should be_nil
    end

    it "gets float32" do
      value = YAML.parse("1.2").as_f32
      value.should eq(1.2_f32)
      value.should be_a(Float32)

      expect_raises(TypeCastError) { YAML.parse("true").as_f32 }

      value = YAML.parse("1.2").as_f32?
      value.should eq(1.2_f32)
      value.should be_a(Float32)

      value = YAML.parse("true").as_f32?
      value.should be_nil
    end

    it "gets float32 from JSON integer (#8618)" do
      value = YAML.parse("123").as_f32
      value.should eq(123.0)
      value.should be_a(Float32)

      value = YAML.parse("123").as_f32?
      value.should eq(123.0)
      value.should be_a(Float32)
    end

    it "gets float64" do
      value = YAML.parse("1.2").as_f
      value.should eq(1.2)
      value.should be_a(Float64)

      expect_raises(TypeCastError) { YAML.parse("true").as_f }

      value = YAML.parse("1.2").as_f?
      value.should eq(1.2)
      value.should be_a(Float64)

      value = YAML.parse("true").as_f?
      value.should be_nil
    end

    it "gets float64 from JSON integer (#8618)" do
      value = YAML.parse("123").as_f
      value.should eq(123.0)
      value.should be_a(Float64)

      value = YAML.parse("123").as_f?
      value.should eq(123.0)
      value.should be_a(Float64)
    end

    it "gets time" do
      value = YAML.parse("2010-01-02").as_time
      value.should eq(Time.utc(2010, 1, 2))

      value = YAML.parse("2010-01-02").as_time?
      value.should eq(Time.utc(2010, 1, 2))

      value = YAML.parse("hello").as_time?
      value.should be_nil
    end

    it "gets bytes" do
      value = YAML.parse("!!binary aGVsbG8=").as_bytes
      value.should eq("hello".to_slice)

      value = YAML.parse("!!binary aGVsbG8=").as_bytes?
      value.should eq("hello".to_slice)

      value = YAML.parse("1").as_bytes?
      value.should be_nil
    end

    it "gets anchor" do
      value = YAML.parse("&foo bar").as_s
      value.should eq "bar"

      value = YAML.parse("- &foo bar\n- *foo").as_a.map(&.as_s)
      value.should eq ["bar", "bar"]

      value = YAML.parse("foo: &foo\n  bar: *foo").as_h
      foo = {YAML::Any.new("bar") => YAML::Any.new(nil)}
      foo[YAML::Any.new("bar")] = YAML::Any.new(foo)
      hash = YAML::Any.new({YAML::Any.new("foo") => YAML::Any.new(foo)})
      # FIXME: Using to_s here because comparison of recursive YAML structures seems to be broken.
      value.to_s.should eq hash.to_s

      expect_raises YAML::ParseException, "Unknown anchor 'foo' at line 1, column 1" do
        YAML.parse("*foo")
      end
    end

    it "gets yes/no unquoted booleans" do
      YAML.parse("yes").as_bool.should be_true
      YAML.parse("no").as_bool.should be_false
      YAML.parse("'yes'").as_bool?.should be_nil
      YAML.parse("'no'").as_bool?.should be_nil
      YAML::Any.from_yaml("yes").as_bool.should be_true
      YAML::Any.from_yaml("no").as_bool.should be_false
      YAML::Any.from_yaml("'yes'").as_bool?.should be_nil
      YAML::Any.from_yaml("'no'").as_bool?.should be_nil
    end

    it "doesn't get quoted numbers" do
      YAML.parse("1").as_i64.should eq(1)
      YAML.parse("'1'").as_i64?.should be_nil
      YAML.parse("'1'").as_s?.should eq("1")
      YAML::Any.from_yaml("1").as_i64.should eq(1)
      YAML::Any.from_yaml("'1'").as_i64?.should be_nil
      YAML::Any.from_yaml("'1'").as_s?.should eq("1")
    end
  end

  describe "#size" do
    it "of array" do
      YAML.parse("- foo\n- bar\n").size.should eq(2)
    end

    it "of hash" do
      YAML.parse("foo: bar").size.should eq(1)
    end
  end

  describe "#[]" do
    it "of array" do
      YAML.parse("- foo\n- bar\n")[1].raw.should eq("bar")

      any = YAML::Any.new([YAML::Any.new("baz"), YAML::Any.new("bar")])

      any[1i64].raw.should eq("bar")
      any[1i32].raw.should eq("bar")
      any[1u8].raw.should eq("bar")

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[nil]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[YAML::Any.new(nil)]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any["fox"]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[YAML::Any.new("fox")]
      end

      expect_raises(IndexError, %(Index out of bounds)) do
        any[2]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[YAML::Any.new(2i64)]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[2.0f64]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[YAML::Any.new(2.0f64)]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[2.0f32]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any[YAML::Any.new(2.0f32)]
      end

      expect_raises(Exception, %(Expected int key for Array#[], not Array(YAML::Any))) do
        any['c']
      end
    end

    context "hash" do
      it_fetches_from_hash nil
      it_fetches_from_hash true
      it_fetches_from_hash 1i64, 1.0f64, 1i32, 1u8, 1.0f32
      it_fetches_from_hash 1.0f64, 1i64, 1i32, 1u8, 1.0f32
      it_fetches_from_hash "foo"
      it_fetches_from_hash Time.utc
      it_fetches_from_hash "foo".to_slice
      it_fetches_from_hash [YAML::Any.new("foo")]
      it_fetches_from_hash({YAML::Any.new("foo") => YAML::Any.new("baz")})
      it_fetches_from_hash Set{YAML::Any.new("foo")}
    end
  end

  describe "#[]?" do
    it "of array" do
      YAML.parse("- foo\n- bar\n")[1]?.not_nil!.raw.should eq("bar")
      YAML.parse("- foo\n- bar\n")[3]?.should be_nil

      any = YAML::Any.new([YAML::Any.new("baz"), YAML::Any.new("bar")])

      any[1i64]?.try(&.raw).should eq("bar")
      any[1i32]?.try(&.raw).should eq("bar")
      any[1u8]?.try(&.raw).should eq("bar")
      any[1.0f64]?.try(&.raw).should be_nil
      any[1.0f32]?.try(&.raw).should be_nil

      any[nil]?.should be_nil
      any[YAML::Any.new(nil)]?.should be_nil
      any["fox"]?.should be_nil
      any[YAML::Any.new("fox")]?.should be_nil
      any[2]?.should be_nil
      any[YAML::Any.new(2i64)]?.should be_nil
      any[2.0f64]?.should be_nil
      any[YAML::Any.new(2.0f64)]?.should be_nil
      any[2.0f32]?.should be_nil
      any[YAML::Any.new(2.0f32)]?.should be_nil
      any['c']?.should be_nil
    end

    it "of hash" do
      YAML.parse("foo: bar")["foo"]?.not_nil!.raw.should eq("bar")
      YAML.parse("foo: bar")["fox"]?.should be_nil
    end

    it "of hash with integer keys" do
      YAML.parse("1: bar")[1]?.not_nil!.raw.should eq("bar")
      YAML.parse("1: bar")[2]?.should be_nil
    end

    context "hash" do
      it_fetches_from_hash? nil
      it_fetches_from_hash? true
      it_fetches_from_hash? 1i64, 1.0
      it_fetches_from_hash? 1.0, 1i64
      it_fetches_from_hash? "foo"
      it_fetches_from_hash? Time.utc
      it_fetches_from_hash? "foo".to_slice
      it_fetches_from_hash? [YAML::Any.new("foo")]
      it_fetches_from_hash?({YAML::Any.new("foo") => YAML::Any.new("baz")})
      it_fetches_from_hash? Set{YAML::Any.new("foo")}
    end
  end

  describe "#dig?" do
    it "gets the value at given path given splat" do
      obj = YAML.parse("--- \nfoo: \n  bar: \n    baz: \n      - qux\n      - fox")

      obj.dig?("foo", "bar", "baz").should eq(%w(qux fox))
      obj.dig?("foo", "bar", "baz", 1).should eq("fox")
    end

    it "returns nil if not found" do
      obj = YAML.parse("--- \nfoo: \n  bar: \n    baz: \n      - qux\n      - fox")

      obj.dig?("foo", 10).should be_nil
      obj.dig?("bar", "baz").should be_nil
      obj.dig?("").should be_nil
    end

    it "returns nil for non-Hash/Array intermediary values" do
      YAML::Any.new(nil).dig?("foo").should be_nil
      YAML::Any.new(0.0).dig?("foo").should be_nil
    end
  end

  describe "dig" do
    it "gets the value at given path given splat" do
      obj = YAML.parse("--- \nfoo: \n  bar: \n    baz: \n      - qux\n      - fox")

      obj.dig("foo", "bar", "baz").should eq(%w(qux fox))
      obj.dig("foo", "bar", "baz", 1).should eq("fox")
    end

    it "raises if not found" do
      obj = YAML.parse("--- \nfoo: \n  bar: \n    baz: \n      - qux\n      - fox")

      expect_raises KeyError, %(Missing hash key: 1) do
        obj.dig("foo", 1, "bar", "baz")
      end
      expect_raises KeyError, %(Missing hash key: "bar") do
        obj.dig("bar", "baz")
      end
      expect_raises KeyError, %(Missing hash key: "") do
        obj.dig("")
      end
    end
  end

  it "traverses big structure" do
    obj = YAML.parse("--- \nfoo: \n  bar: \n    baz: \n      - qux\n      - fox")
    obj["foo"]["bar"]["baz"][1].as_s.should eq("fox")
  end

  it "compares to other objects" do
    obj = YAML.parse("- foo\n- bar \n")
    obj.should eq(%w(foo bar))
    obj[0].should eq("foo")
  end

  it "returns array of any when doing parse all" do
    docs = YAML.parse_all("---\nfoo\n---\nbar\n")
    docs[0].as_s.should eq("foo")
    docs[1].as_s.should eq("bar")
  end

  it "can compare with ===" do
    (1 === YAML.parse("1")).should be_truthy
  end

  it "exposes $~ when doing Regex#===" do
    (/o+/ === YAML.parse(%("foo"))).should be_truthy
    $~[0].should eq("oo")
  end

  it "is enumerable" do
    nums = YAML.parse("[1, 2, 3]")
    nums.as_a.each_with_index do |x, i|
      x.should be_a(YAML::Any)
      x.raw.should eq(i + 1)
    end
  end

  it "dups" do
    any = YAML.parse("[1, 2, 3]")
    any2 = any.dup
    any2.as_a.should_not be(any.as_a)
  end

  it "clones" do
    any = YAML.parse("[[1], 2, 3]")
    any2 = any.clone
    any2.as_a[0].as_a.should_not be(any.as_a[0].as_a)
  end

  it "#to_json" do
    any = YAML.parse <<-YAML
      foo: bar
      baz: [1, 2.3, true, "qux", {"qax": "qox"}]
      YAML
    any.to_json.should eq %({"foo":"bar","baz":[1,2.3,true,"qux",{"qax":"qox"}]})
  end
end
