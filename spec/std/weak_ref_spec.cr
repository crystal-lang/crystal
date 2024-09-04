require "spec"
require "weak_ref"
require "../support/finalize"

private class Foo
  include FinalizeCounter

  def initialize(@key : String)
  end
end

describe WeakRef do
  it "should get dereferenced object" do
    foo = Foo.new("foo")
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

  it "FinalizeState counts released objects" do
    FinalizeState.reset
    FinalizeState.count("foo").should eq 0
    10.times do
      Foo.new("foo")
    end
    GC.collect
    FinalizeState.count("foo").should be > 0
  end

  it "Referenced object should not be released" do
    FinalizeState.reset
    instances = [] of Foo
    FinalizeState.count("strong_foo_ref").should eq 0
    10.times do
      instances << Foo.new("strong_foo_ref")
    end
    GC.collect
    FinalizeState.count("strong_foo_ref").should eq 0
  end

  it "Weak referenced object should be released if no other reference" do
    FinalizeState.reset
    instances = [] of WeakRef(Foo)
    last = nil
    10.times do
      last = Foo.new("weak_foo_ref")
      instances << WeakRef.new(last)
    end
    GC.collect
    FinalizeState.count("weak_foo_ref").should be > 0
    instances.count { |wr| wr.value.nil? }.should be > 0
    instances[-1].value.should_not be_nil

    # Use `last` to stop the variable from being optimised away in release mode.
    last.to_s
  end
end
