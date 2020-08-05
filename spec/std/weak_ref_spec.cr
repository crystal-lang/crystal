require "spec"
require "weak_ref"

private class State
  @@count = {} of Symbol => Int64

  def self.inc(key)
    @@count[key] = @@count.fetch(key, 0i64) + 1
  end

  def self.count(key)
    @@count.fetch(key, 0i64)
  end

  def self.reset
    @@count.clear
  end
end

private class Foo
  def initialize(@key : Symbol)
  end

  def finalize
    State.inc @key
  end
end

describe WeakRef do
  it "should get dereferenced object" do
    foo = Foo.new :foo
    ref = WeakRef.new(foo)
    ref.should_not be_nil
    ref.value.should be(foo)
  end

  it "should get dereferenced object in data section" do
    foo = "foo"
    ref = WeakRef.new(foo)
    ref.value.should be(foo)
  end

  it "should not crash with object in data section during GC" do
    foo = "foo"
    ref = WeakRef.new(foo)
    GC.collect
  end

  it "State counts released objects" do
    State.reset
    State.count(:foo).should eq 0
    10.times do
      Foo.new(:foo)
    end
    GC.collect
    State.count(:foo).should be > 0
  end

  it "Referenced object should not be released" do
    State.reset
    instances = [] of Foo
    State.count(:strong_foo_ref).should eq 0
    10.times do
      instances << Foo.new(:strong_foo_ref)
    end
    GC.collect
    State.count(:strong_foo_ref).should eq 0
  end

  it "Weak referenced object should be released if no other reference" do
    State.reset
    instances = [] of WeakRef(Foo)
    last = nil
    10.times do
      last = Foo.new(:weak_foo_ref)
      instances << WeakRef.new(last)
    end
    GC.collect
    State.count(:weak_foo_ref).should be > 0
    instances.select { |wr| wr.value.nil? }.size.should be > 0
    instances[-1].value.should_not be_nil

    # Use `last` to stop the variable from being optimised away in release mode.
    last.to_s
  end
end
