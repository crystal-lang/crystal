require "../../spec_helper"

private class HierarchyObserverProbe
  include Crystal::HierarchyObserver

  getter notifications = 0
  property callback : Proc(Nil)?

  def watch(type : Crystal::Type)
    observe_hierarchy(type)
  end

  def subscribe(type : Crystal::Type)
    subscribe_to_hierarchy(type)
  end

  def subscription_count
    @observed_hierarchies.try(&.size) || 0
  end

  def on_new_subclass
    @notifications += 1
    @callback.try &.call
  end
end

describe Crystal::HierarchyObserver do
  it "observes non-recursive branches of a recursive alias" do
    program = semantic(<<-CRYSTAL).program
      abstract class Base; end
      class Box(T); end
      alias Node = Base | Box(Node)
      CRYSTAL
    observer = HierarchyObserverProbe.new
    observer.watch(program.types["Node"])

    observer.subscription_count.should eq(1)
    program.types["Base"].as(SubclassObservable).notify_subclass_added
    observer.notifications.should eq(1)
  end

  it "keeps shared argument and receiver subscriptions when the receiver changes" do
    program = semantic(<<-CRYSTAL).program
      abstract class Base; end
      class Child < Base; end
      class Other; end
      CRYSTAL
    base = program.types["Base"]
    child = program.types["Child"]
    other = program.types["Other"]
    observer = HierarchyObserverProbe.new

    observer.watch(base.virtual_type)
    observer.subscribe(base)
    observer.subscribe(child)
    observer.subscribe(other)

    observer.subscription_count.should eq(3)
    base.as(SubclassObservable).notify_subclass_added
    child.as(SubclassObservable).notify_subclass_added
    other.as(SubclassObservable).notify_subclass_added
    observer.notifications.should eq(3)
  end

  it "does not accumulate links when the same wrappers are observed repeatedly" do
    program = semantic("abstract class Base; end").program
    base = program.types["Base"]
    wrapped = program.tuple_of([base.virtual_type] of Type)
    observer = HierarchyObserverProbe.new

    100.times do
      observer.watch(wrapped)
      observer.watch(base.virtual_type)
      observer.subscribe(base)
    end

    observer.subscription_count.should eq(1)
    base.as(SubclassObservable).notify_subclass_added
    observer.notifications.should eq(1)
  end

  it "uses a notification snapshot when a callback adds another observer" do
    program = semantic("abstract class Base; end").program
    base = program.types["Base"]
    first = HierarchyObserverProbe.new
    second = HierarchyObserverProbe.new
    late = HierarchyObserverProbe.new
    first.callback = -> { late.watch(base.virtual_type); nil }
    first.watch(base.virtual_type)
    second.watch(base.virtual_type)

    base.as(SubclassObservable).notify_subclass_added
    {first.notifications, second.notifications, late.notifications}.should eq({1, 1, 0})
    base.as(SubclassObservable).notify_subclass_added
    {first.notifications, second.notifications, late.notifications}.should eq({2, 2, 1})
  end

  it "allows a callback to instantiate another member of an observed hierarchy" do
    program = semantic(<<-CRYSTAL).program
      abstract class Base; end
      class Child(T) < Base; end
      CRYSTAL
    base = program.types["Base"]
    child = program.types["Child"].as(GenericClassType)
    observer = HierarchyObserverProbe.new
    nested = false
    observer.callback = -> {
      unless nested
        nested = true
        child.instantiate([program.int64] of TypeVar)
      end
      nil
    }
    observer.watch(base.virtual_type)

    child.instantiate([program.int32] of TypeVar)

    nested.should be_true
    child.instantiated_types.size.should eq(2)
    observer.notifications.should be > 1
    observer.subscription_count.should eq(1)
  end
end
