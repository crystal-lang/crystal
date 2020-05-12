require "spec"
require "log"
require "log/json"

private def m(value)
  Log::Metadata.build(value)
end

private def v(value)
  Log::Metadata::Value.new(value)
end

describe Log::Metadata do
  it "empty" do
    Log::Metadata.empty.should eq(Log::Metadata.new)
    Log::Metadata.empty.object_id.should_not eq(Log::Metadata.new.object_id)
    Log::Metadata.empty.object_id.should eq(Log::Metadata.empty.object_id)
  end

  it "extend" do
    m({a: 1}).extend({b: 2}).should eq(m({a: 1, b: 2}))
    m({a: 1, b: 3}).extend({b: 2}).should eq(m({a: 1, b: 2}))
    m({a: 1, b: 3}).extend({b: nil}).should eq(m({a: 1, b: nil}))
  end

  it "extend against empty values without creating a new instance" do
    c1 = m({a: 1, b: 3})
    c1.extend(NamedTuple.new).should be(c1)
    c1.extend(Hash(Symbol, String).new).should be(c1)
  end

  it "json" do
    m({a: 1}).to_json.should eq(%({"a":1}))
    m({a: 1, b: 1}).extend({b: 2}).to_json.should eq(%({"b":2,"a":1}))
  end
end

describe Log::Metadata::Value do
  it "initialize" do
    v({a: 1}).should eq(v({"a" => v(1)}))
    v({a: 1, b: ["str", true], num: 1i64}).should eq(v({"a" => v(1), "b" => v([v("str"), v(true)]), "num" => v(1i64)}))
    v({a: 1f32, b: 1f64}).should eq(v({"a" => v(1f32), "b" => v(1f64)}))
    t = Time.local
    v({time: t}).should eq(v({"time" => v(t)}))
    v({} of String => String).should eq(v(NamedTuple.new))
  end

  it "accessors" do
    v(nil).as_nil.should be_nil

    v(1).as_i.should eq(1)

    v("a").as_s.should eq("a")
    v(1).as_s?.should be_nil

    v(true).as_bool.should eq(true)
    v(false).as_bool.should eq(false)
    v(true).as_bool?.should eq(true)
    v(false).as_bool?.should eq(false)
    v(nil).as_bool?.should be_nil
  end

  it "json" do
    v({a: 1}).to_json.should eq(%({"a":1}))
  end
end
