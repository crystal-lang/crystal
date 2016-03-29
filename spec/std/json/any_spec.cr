require "spec"
require "json"

describe JSON::Any do
  describe "casts" do
    it "gets nil" do
      JSON.parse("null").as_nil.should be_nil
    end

    it "gets bool" do
      JSON.parse("true").as_bool.should be_true
      JSON.parse("false").as_bool.should be_false
    end

    it "gets int" do
      JSON.parse("123").as_i.should eq(123)
      JSON.parse("123456789123456").as_i64.should eq(123456789123456)
    end

    it "gets float" do
      JSON.parse("123.45").as_f.should eq(123.45)
      JSON.parse("123.45").as_f32.should eq(123.45_f32)
    end

    it "gets string" do
      JSON.parse(%("hello")).as_s.should eq("hello")
    end

    it "gets array" do
      JSON.parse(%([1, 2, 3])).as_a.should eq([1, 2, 3])
    end

    it "gets hash" do
      JSON.parse(%({"foo": "bar"})).as_h.should eq({"foo": "bar"})
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
    end

    it "of hash" do
      JSON.parse(%({"foo": "bar"}))["foo"]?.not_nil!.raw.should eq("bar")
      JSON.parse(%({"foo": "bar"}))["fox"]?.should be_nil
    end
  end

  describe "each" do
    it "of array" do
      elems = [] of Int32
      JSON.parse("[1, 2, 3]").each do |any|
        elems << any.as_i
      end
      elems.should eq([1, 2, 3])
    end

    it "of hash" do
      elems = [] of String
      JSON.parse(%({"foo": "bar"})).each do |key, value|
        elems << key.to_s << value.to_s
      end
      elems.should eq(%w(foo bar))
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
end
