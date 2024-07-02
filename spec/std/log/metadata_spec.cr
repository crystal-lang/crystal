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

  it "empty?" do
    Log::Metadata.empty.should be_empty
    m({} of Symbol => String).should be_empty
    Log::Metadata.new.should be_empty
    m({} of Symbol => String).extend({} of Symbol => String).should be_empty

    m({a: 1}).should_not be_empty
    m({} of Symbol => String).extend({a: 1}).should_not be_empty
    m({a: 1}).extend({} of Symbol => String).should_not be_empty
  end

  describe "#dup" do
    it "creates a shallow copy" do
      Log::Metadata.empty.dup.should eq(Log::Metadata.empty)
      m({a: 1}).dup.should eq(m({a: 1}))
      m({a: 1, b: 3}).dup.should eq(m({a: 1, b: 3}))
    end
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

  it "==" do
    m({} of Symbol => String).should eq(m({} of Symbol => String))
    m({a: 1}).should eq(m({a: 1}))
    m({a: 1, b: 2}).should eq(m({b: 2, a: 1}))

    m({a: 1}).should_not eq(m({a: 2}))
    m({a: 1}).should_not eq(m({b: 1}))

    m({a: 1}).extend({b: 2}).should eq(m({b: 2}).extend({a: 1}))
    m({a: 1, b: 1}).extend({b: 2}).should eq(m({b: 2}).extend({a: 1}))
    m({a: 1, b: 2}).extend({b: 1}).should eq(m({a: 1, b: 1}))
  end

  it "json" do
    m({a: 1}).to_json.should eq(%({"a":1}))
    m({a: 1, b: 1}).extend({b: 2}).to_json.should eq(%({"b":2,"a":1}))
  end

  it "defrags" do
    parent = m({a: 1, b: 2}).extend({a: 2})
    md = parent.extend({a: 3})

    md.@size.should eq(1)
    md.@max_total_size.should eq(4)
    md.@overridden_size.should eq(1)
    md.@parent.should be(parent)

    md.should eq(m({a: 3, b: 2}))

    md.@size.should eq(2)
    md.@max_total_size.should eq(2)
    md.@overridden_size.should eq(1)
    md.@parent.should be_nil
  end

  it "[]" do
    md = m({a: 1, b: 2}).extend({a: 3})

    md[:a].should eq(3)
    md[:b].should eq(2)
    expect_raises(KeyError) { md[:c] }
  end

  it "[]?" do
    md = m({a: 1, b: 2}).extend({a: 3})

    md[:a]?.should eq(3)
    md[:b]?.should eq(2)
    md[:c]?.should be_nil
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
