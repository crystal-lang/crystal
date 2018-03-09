require "spec"
require "yaml"

describe YAML::Any do
  describe "casts" do
    it "gets nil" do
      YAML.parse("").as_nil.should be_nil
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

    it "gets float64" do
      value = YAML.parse("1.2").as_f
      value.should eq(1.2)
      value.should be_a(Float64)

      value = YAML.parse("1.2").as_f?
      value.should eq(1.2)
      value.should be_a(Float64)

      value = YAML.parse("true").as_f?
      value.should be_nil
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
    end

    it "of hash" do
      YAML.parse("foo: bar")["foo"].raw.should eq("bar")
    end

    it "of hash with integer keys" do
      YAML.parse("1: bar")[1].raw.should eq("bar")
    end
  end

  describe "#[]?" do
    it "of array" do
      YAML.parse("- foo\n- bar\n")[1]?.not_nil!.raw.should eq("bar")
      YAML.parse("- foo\n- bar\n")[3]?.should be_nil
    end

    it "of hash" do
      YAML.parse("foo: bar")["foo"]?.not_nil!.raw.should eq("bar")
      YAML.parse("foo: bar")["fox"]?.should be_nil
    end

    it "of hash with integer keys" do
      YAML.parse("1: bar")[1]?.not_nil!.raw.should eq("bar")
      YAML.parse("1: bar")[2]?.should be_nil
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
end
