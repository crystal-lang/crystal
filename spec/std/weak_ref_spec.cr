require "spec"
require "weak_ref"

module WeakRefSpec
  class State
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

  class Foo
    def initialize(@key : Symbol)
    end

    def finalize
      State.inc @key
    end
  end
end

describe WeakRef do
  it "should get dereference object" do
    foo = WeakRefSpec::Foo.new :foo
    ref = WeakRef.new(foo)
    ref.should_not be_nil
    ref.target.should be(foo)
  end

  it "WeakRefSpec::State counts released objects" do
    WeakRefSpec::State.reset
    WeakRefSpec::State.count(:foo).should eq 0
    10.times do
      WeakRefSpec::Foo.new(:foo)
    end
    GC.collect
    WeakRefSpec::State.count(:foo).should be > 0
  end

  it "Referenced object should not be released" do
    WeakRefSpec::State.reset
    instances = [] of WeakRefSpec::Foo
    WeakRefSpec::State.count(:strong_foo_ref).should eq 0
    10.times do
      instances << WeakRefSpec::Foo.new(:strong_foo_ref)
    end
    GC.collect
    WeakRefSpec::State.count(:strong_foo_ref).should eq 0
  end

  it "Weak referenced object should be released if no other reference" do
    WeakRefSpec::State.reset
    instances = [] of WeakRef(WeakRefSpec::Foo)
    last = nil
    10.times do
      last = WeakRefSpec::Foo.new(:weak_foo_ref)
      instances << WeakRef.new(last)
    end
    GC.collect
    WeakRefSpec::State.count(:weak_foo_ref).should be > 0
    instances.select { |wr| wr.target.nil? }.size.should be > 0
    instances[-1].target.should_not be_nil
  end
end
