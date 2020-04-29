require "spec"
require "log"
require "log/json"

private def c(value)
  Log::Metadata.new(value)
end

describe Log::Metadata do
  it "initialize" do
    c({a: 1}).should eq(c({"a" => c(1)}))
    c({a: 1, b: ["str", true], num: 1i64}).should eq(c({"a" => c(1), "b" => c([c("str"), c(true)]), "num" => c(1i64)}))
    c({a: 1f32, b: 1f64}).should eq(c({"a" => c(1f32), "b" => c(1f64)}))
    t = Time.local
    c({time: t}).should eq(c({"time" => c(t)}))
    Log::Metadata.new.should eq(c(NamedTuple.new))
  end

  it "empty" do
    Log::Metadata.empty.should eq(Log::Metadata.new)
    Log::Metadata.empty.object_id.should_not eq(Log::Metadata.new.object_id)
    Log::Metadata.empty.object_id.should eq(Log::Metadata.empty.object_id)
  end

  it "immutability" do
    context = c({a: 1})
    other = context.as_h
    other["a"] = c(2)

    other.should eq({"a" => c(2)})
    context.should eq(c({a: 1}))
  end

  it "merge" do
    c({a: 1}).merge(c({b: 2})).should eq(c({a: 1, b: 2}))
    c({a: 1, b: 3}).merge(c({b: 2})).should eq(c({a: 1, b: 2}))
    c({a: 1, b: 3}).merge(c({b: nil})).should eq(c({a: 1, b: nil}))
  end

  it "merge against Log::Metadata.empty without creating a new instance" do
    c1 = c({a: 1, b: 3})
    c1.merge(Log::Metadata.empty).should be(c1)
    Log::Metadata.empty.merge(c1).should be(c1)
  end

  it "accessors" do
    c(nil).as_nil.should be_nil

    c(1).as_i.should eq(1)

    c("a").as_s.should eq("a")
    c(1).as_s?.should be_nil

    c(true).as_bool.should eq(true)
    c(false).as_bool.should eq(false)
    c(true).as_bool?.should eq(true)
    c(false).as_bool?.should eq(false)
    c(nil).as_bool?.should be_nil
  end
end
