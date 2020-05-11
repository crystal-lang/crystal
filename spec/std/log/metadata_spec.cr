require "spec"
require "log"
require "log/json"

private def m(value)
  Log::Metadata.new(value)
end

describe Log::Metadata do
  it "initialize" do
    m({a: 1}).should eq(m({"a" => m(1)}))
    m({a: 1, b: ["str", true], num: 1i64}).should eq(m({"a" => m(1), "b" => m([m("str"), m(true)]), "num" => m(1i64)}))
    m({a: 1f32, b: 1f64}).should eq(m({"a" => m(1f32), "b" => m(1f64)}))
    t = Time.local
    m({time: t}).should eq(m({"time" => m(t)}))
    Log::Metadata.new.should eq(m(NamedTuple.new))
  end

  it "empty" do
    Log::Metadata.empty.should eq(Log::Metadata.new)
    Log::Metadata.empty.object_id.should_not eq(Log::Metadata.new.object_id)
    Log::Metadata.empty.object_id.should eq(Log::Metadata.empty.object_id)
  end

  it "immutability" do
    context = m({a: 1})
    other = context.as_h
    other["a"] = m(2)

    other.should eq({"a" => m(2)})
    context.should eq(m({a: 1}))
  end

  it "nested immutability" do
    context = m({a: {b: 1}})
    other = context.as_h
    other["a"].raw.as(Hash)["b"] = m(2)

    other.should eq({"a" => m({"b" => 2})})
    context.should eq({"a" => m({"b" => 1})})
  end

  it "merge" do
    m({a: 1}).merge(m({b: 2})).should eq(m({a: 1, b: 2}))
    m({a: 1, b: 3}).merge(m({b: 2})).should eq(m({a: 1, b: 2}))
    m({a: 1, b: 3}).merge(m({b: nil})).should eq(m({a: 1, b: nil}))
  end

  it "merge against Log::Metadata.empty without creating a new instance" do
    c1 = m({a: 1, b: 3})
    c1.merge(Log::Metadata.empty).should be(c1)
    Log::Metadata.empty.merge(c1).should be(c1)
  end

  it "accessors" do
    m(nil).as_nil.should be_nil

    m(1).as_i.should eq(1)

    m("a").as_s.should eq("a")
    m(1).as_s?.should be_nil

    m(true).as_bool.should eq(true)
    m(false).as_bool.should eq(false)
    m(true).as_bool?.should eq(true)
    m(false).as_bool?.should eq(false)
    m(nil).as_bool?.should be_nil
  end
end
