require "spec"
require "crystal/event_loop/timers"

private struct Timer
  include Crystal::PointerPairingHeap::Node

  property! wake_at : Time::Span

  def initialize(timeout : Time::Span? = nil)
    @wake_at = Time.monotonic + timeout if timeout
  end

  def heap_compare(other : Pointer(self)) : Bool
    wake_at < other.value.wake_at
  end
end

describe Crystal::EventLoop::Timers do
  it "#empty?" do
    timers = Crystal::EventLoop::Timers(Timer).new
    timers.empty?.should be_true

    event = Timer.new(7.seconds)
    timers.add(pointerof(event))
    timers.empty?.should be_false

    timers.delete(pointerof(event))
    timers.empty?.should be_true
  end

  it "#next_ready?" do
    # empty
    timers = Crystal::EventLoop::Timers(Timer).new
    timers.next_ready?.should be_nil

    # with events
    event1s = Timer.new(1.second)
    event3m = Timer.new(3.minutes)
    event5m = Timer.new(5.minutes)

    timers.add(pointerof(event5m))
    timers.next_ready?.should eq(event5m.wake_at?)

    timers.add(pointerof(event1s))
    timers.next_ready?.should eq(event1s.wake_at?)

    timers.add(pointerof(event3m))
    timers.next_ready?.should eq(event1s.wake_at?)
  end

  it "#dequeue_ready" do
    timers = Crystal::EventLoop::Timers(Timer).new

    event1 = Timer.new(0.seconds)
    event2 = Timer.new(0.seconds)
    event3 = Timer.new(1.minute)

    # empty
    called = 0
    timers.dequeue_ready { called += 1 }
    called.should eq(0)

    # add events in non chronological order
    timers = Crystal::EventLoop::Timers(Timer).new
    timers.add(pointerof(event1))
    timers.add(pointerof(event3))
    timers.add(pointerof(event2))

    events = [] of Timer*
    timers.dequeue_ready { |event| events << event }

    events.should eq([
      pointerof(event1),
      pointerof(event2),
    ])
    timers.empty?.should be_false
  end

  it "#add" do
    timers = Crystal::EventLoop::Timers(Timer).new

    event0 = Timer.new
    event1 = Timer.new(0.seconds)
    event2 = Timer.new(2.minutes)
    event3 = Timer.new(1.minute)

    # add events in non chronological order
    timers.add(pointerof(event1)).should be_true # added to the head (next ready)
    timers.add(pointerof(event2)).should be_false
    timers.add(pointerof(event3)).should be_false

    event0.wake_at = -1.minute
    timers.add(pointerof(event0)).should be_true # added new head (next ready)
  end

  it "#delete" do
    event1 = Timer.new(0.seconds)
    event2 = Timer.new(0.seconds)
    event3 = Timer.new(1.minute)
    event4 = Timer.new(4.minutes)

    # add events in non chronological order
    timers = Crystal::EventLoop::Timers(Timer).new
    timers.add(pointerof(event1))
    timers.add(pointerof(event3))
    timers.add(pointerof(event2))

    timers.delete(pointerof(event1)).should eq({true, true})  # dequeued+removed head (next ready)
    timers.delete(pointerof(event3)).should eq({true, false}) # dequeued
    timers.delete(pointerof(event2)).should eq({true, true})  # dequeued+removed new head (next ready)
    timers.empty?.should be_true
    timers.delete(pointerof(event2)).should eq({false, false}) # not dequeued
    timers.delete(pointerof(event4)).should eq({false, false}) # not dequeued
  end
end
