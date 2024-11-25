{% skip_file unless Crystal.has_constant?(:Evented) %}

require "spec"

describe Crystal::Evented::Timers do
  it "#empty?" do
    timers = Crystal::Evented::Timers.new
    timers.empty?.should be_true

    event = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 7.seconds)
    timers.add(pointerof(event))
    timers.empty?.should be_false

    timers.delete(pointerof(event))
    timers.empty?.should be_true
  end

  it "#next_ready?" do
    # empty
    timers = Crystal::Evented::Timers.new
    timers.next_ready?.should be_nil

    # with events
    event1s = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 1.second)
    event3m = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 3.minutes)
    event5m = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 5.minutes)

    timers.add(pointerof(event5m))
    timers.next_ready?.should eq(event5m.wake_at?)

    timers.add(pointerof(event1s))
    timers.next_ready?.should eq(event1s.wake_at?)

    timers.add(pointerof(event3m))
    timers.next_ready?.should eq(event1s.wake_at?)
  end

  it "#dequeue_ready" do
    timers = Crystal::Evented::Timers.new

    event1 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 0.seconds)
    event2 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 0.seconds)
    event3 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 1.minute)

    # empty
    called = 0
    timers.dequeue_ready { called += 1 }
    called.should eq(0)

    # add events in non chronological order
    timers = Crystal::Evented::Timers.new
    timers.add(pointerof(event1))
    timers.add(pointerof(event3))
    timers.add(pointerof(event2))

    events = [] of Crystal::Evented::Event*
    timers.dequeue_ready { |event| events << event }

    events.should eq([
      pointerof(event1),
      pointerof(event2),
    ])
    timers.empty?.should be_false
  end

  it "#add" do
    timers = Crystal::Evented::Timers.new

    event0 = Crystal::Evented::Event.new(:sleep, Fiber.current)
    event1 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 0.seconds)
    event2 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 2.minutes)
    event3 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 1.minute)

    # add events in non chronological order
    timers.add(pointerof(event1)).should be_true # added to the head (next ready)
    timers.add(pointerof(event2)).should be_false
    timers.add(pointerof(event3)).should be_false

    event0.wake_at = -1.minute
    timers.add(pointerof(event0)).should be_true # added new head (next ready)
  end

  it "#delete" do
    event1 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 0.seconds)
    event2 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 0.seconds)
    event3 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 1.minute)
    event4 = Crystal::Evented::Event.new(:sleep, Fiber.current, timeout: 4.minutes)

    # add events in non chronological order
    timers = Crystal::Evented::Timers.new
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
