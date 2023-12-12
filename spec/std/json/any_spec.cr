require "../spec_helper"
require "json"
require "yaml"

describe JSON::Any do
  it ".new" do
    JSON::Any.new(nil).raw.should be_nil
    JSON::Any.new(true).raw.should eq true
    JSON::Any.new(1_i64).raw.should eq 1_i64
    JSON::Any.new(1).raw.should eq 1
    JSON::Any.new(1_u8).raw.should eq 1
    JSON::Any.new(0.0).raw.should eq 0.0
    JSON::Any.new(0.0_f32).raw.should eq 0.0
    JSON::Any.new("foo").raw.should eq "foo"
    JSON::Any.new([] of JSON::Any).raw.should eq [] of JSON::Any
    JSON::Any.new({} of String => JSON::Any).raw.should eq({} of String => JSON::Any)
  end

  describe "casts" do
    it "gets nil" do
      JSON.parse("null").as_nil.should be_nil
    end

    it "gets bool" do
      JSON.parse("true").as_bool.should be_true
      JSON.parse("false").as_bool.should be_false
      JSON.parse("true").as_bool?.should be_true
      JSON.parse("false").as_bool?.should be_false
      JSON.parse("2").as_bool?.should be_nil
    end

    it "gets int32" do
      JSON.parse("123").as_i.should eq(123)
      JSON.parse("123").as_i?.should eq(123)
      JSON.parse("true").as_i?.should be_nil
    end

    it "gets int64" do
      JSON.parse("123456789123456").as_i64.should eq(123456789123456)
      JSON.parse("123456789123456").as_i64?.should eq(123456789123456)
      JSON.parse("true").as_i64?.should be_nil
    end

    it "gets float32" do
      JSON.parse("123.45").as_f32.should eq(123.45_f32)
      expect_raises(TypeCastError) { JSON.parse("true").as_f32 }
      JSON.parse("123.45").as_f32?.should eq(123.45_f32)
      JSON.parse("true").as_f32?.should be_nil
    end

    it "gets float32 from JSON integer (#8618)" do
      value = JSON.parse("123").as_f32
      value.should eq(123.0)
      value.should be_a(Float32)

      value = JSON.parse("123").as_f32?
      value.should eq(123.0)
      value.should be_a(Float32)
    end

    it "gets float64" do
      JSON.parse("123.45").as_f.should eq(123.45)
      expect_raises(TypeCastError) { JSON.parse("true").as_f }
      JSON.parse("123.45").as_f?.should eq(123.45)
      JSON.parse("true").as_f?.should be_nil
    end

    it "gets float64 from JSON integer (#8618)" do
      value = JSON.parse("123").as_f
      value.should eq(123.0)
      value.should be_a(Float64)

      value = JSON.parse("123").as_f?
      value.should eq(123.0)
      value.should be_a(Float64)
    end

    it "gets string" do
      JSON.parse(%("hello")).as_s.should eq("hello")
      JSON.parse(%("hello")).as_s?.should eq("hello")
      JSON.parse("true").as_s?.should be_nil
    end

    it "gets array" do
      JSON.parse(%([1, 2, 3])).as_a.should eq([1, 2, 3])
      JSON.parse(%([1, 2, 3])).as_a?.should eq([1, 2, 3])
      JSON.parse("true").as_a?.should be_nil
    end

    it "gets hash" do
      JSON.parse(%({"foo": "bar"})).as_h.should eq({"foo" => "bar"})
      JSON.parse(%({"foo": "bar"})).as_h?.should eq({"foo" => "bar"})
      JSON.parse("true").as_h?.should be_nil
    end
  end

  describe "#size" do
    it "of array" do
      JSON.parse("[1, 2, 3]").size.should eq(3)
    end

    it "of hash" do
      JSON.parse(%({"foo": "bar"})).size.should eq(1)
    end
  end

  describe "#[]" do
    it "of array" do
      JSON.parse("[1, 2, 3]")[1].raw.should eq(2)
    end

    it "of hash" do
      JSON.parse(%({"foo": "bar"}))["foo"].raw.should eq("bar")
    end
  end

  describe "#[]?" do
    it "of array" do
      JSON.parse("[1, 2, 3]")[1]?.not_nil!.raw.should eq(2)
      JSON.parse("[1, 2, 3]")[3]?.should be_nil
      JSON.parse("[true, false]")[1]?.should eq false
    end

    it "of hash" do
      JSON.parse(%({"foo": "bar"}))["foo"]?.not_nil!.raw.should eq("bar")
      JSON.parse(%({"foo": "bar"}))["fox"]?.should be_nil
      JSON.parse(%q<{"foo": false}>)["foo"]?.should eq false
    end
  end

  describe "#dig?" do
    it "gets the value at given path given splat" do
      obj = JSON.parse(%({"foo": [1, {"bar": [2, 3]}]}))

      obj.dig?("foo", 0).should eq(1)
      obj.dig?("foo", 1, "bar", 1).should eq(3)
    end

    it "returns nil if not found" do
      obj = JSON.parse(%({"foo": [1, {"bar": [2, 3]}]}))

      obj.dig?("foo", 10).should be_nil
      obj.dig?("bar", "baz").should be_nil
      obj.dig?("").should be_nil
    end

    it "returns nil for non-Hash/Array intermediary values" do
      JSON::Any.new(nil).dig?("foo").should be_nil
      JSON::Any.new(0.0).dig?("foo").should be_nil
    end
  end

  describe "dig" do
    it "gets the value at given path given splat" do
      obj = JSON.parse(%({"foo": [1, {"bar": [2, 3]}]}))

      obj.dig("foo", 0).should eq(1)
      obj.dig("foo", 1, "bar", 1).should eq(3)
    end

    it "raises if not found" do
      obj = JSON.parse(%({"foo": [1, {"bar": [2, 3]}]}))

      expect_raises Exception, %(Expected Hash for #[](key : String), not Array(JSON::Any)) do
        obj.dig("foo", 1, "bar", "baz")
      end
      expect_raises KeyError, %(Missing hash key: "z") do
        obj.dig("z")
      end
      expect_raises KeyError, %(Missing hash key: "") do
        obj.dig("")
      end
    end
  end

  it "traverses big structure" do
    obj = JSON.parse(%({"foo": [1, {"bar": [2, 3]}]}))
    obj["foo"][1]["bar"][1].as_i.should eq(3)
  end

  it "compares to other objects" do
    obj = JSON.parse(%([1, 2]))
    obj.should eq([1, 2])
    obj[0].should eq(1)
  end

  it "can compare with ===" do
    (1 === JSON.parse("1")).should be_truthy
  end

  it "exposes $~ when doing Regex#===" do
    (/o+/ === JSON.parse(%("foo"))).should be_truthy
    $~[0].should eq("oo")
  end

  it "dups" do
    any = JSON.parse("[1, 2, 3]")
    any2 = any.dup
    any2.as_a.should_not be(any.as_a)
  end

  it "clones" do
    any = JSON.parse("[[1], 2, 3]")
    any2 = any.clone
    any2.as_a[0].as_a.should_not be(any.as_a[0].as_a)
  end

  it "#to_yaml" do
    any = JSON.parse <<-JSON
      {
        "foo": "bar",
        "baz": [1, 2.3, true, "qux", {"qax": "qox"}]
      }
      JSON
    any.to_yaml.should eq <<-YAML
      ---
      foo: bar
      baz:
      - 1
      - 2.3
      - true
      - qux
      - qax: qox

      YAML
  end
end
