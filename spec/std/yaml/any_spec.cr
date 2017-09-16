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
  end

  describe "each" do
    it "of array" do
      elems = [] of String
      YAML.parse("- foo\n- bar\n").each do |any|
        elems << any.as_s
      end
      elems.should eq(%w(foo bar))
    end

    it "of hash" do
      elems = [] of String
      YAML.parse("foo: bar").each do |key, value|
        elems << key.to_s << value.to_s
      end
      elems.should eq(%w(foo bar))
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
    ("1" === YAML.parse("1")).should be_truthy
  end

  it "exposes $~ when doing Regex#===" do
    (/o+/ === YAML.parse(%("foo"))).should be_truthy
    $~[0].should eq("oo")
  end

  it "is enumerable" do
    nums = YAML.parse("[1, 2, 3]")
    nums.each_with_index do |x, i|
      x.should be_a(YAML::Any)
      x.raw.should eq((i + 1).to_s)
    end
  end
end
