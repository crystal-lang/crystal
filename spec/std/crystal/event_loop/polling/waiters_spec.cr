{% skip_file unless Crystal::EventLoop.has_constant?(:Polling) %}

require "spec"

describe Crystal::EventLoop::Polling::Waiters do
  describe "#add" do
    it "adds event to list" do
      waiters = Crystal::EventLoop::Polling::Waiters.new

      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      ret = waiters.add(pointerof(event))
      ret.should be_true
    end

    it "doesn't add the event when the list is ready (race condition)" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      waiters.ready_one { true }

      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      ret = waiters.add(pointerof(event))
      ret.should be_false
      waiters.@ready.should be_false
    end

    it "doesn't add the event when the list is always ready" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      waiters.ready_all { }

      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      ret = waiters.add(pointerof(event))
      ret.should be_false
      waiters.@always_ready.should be_true
    end
  end

  describe "#delete" do
    it "removes the event from the list" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)

      waiters.add(pointerof(event))
      waiters.delete(pointerof(event))

      called = false
      waiters.ready_one { called = true }
      called.should be_false
    end

    it "does nothing when the event isn't in the list" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      waiters.delete(pointerof(event))
    end
  end

  describe "#ready_one" do
    it "marks the list as ready when empty (race condition)" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      called = false

      waiters.ready_one { called = true }

      called.should be_false
      waiters.@ready.should be_true
    end

    it "dequeues events in FIFO order" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      event1 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event2 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event3 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      called = 0

      waiters.add(pointerof(event1))
      waiters.add(pointerof(event2))
      waiters.add(pointerof(event3))

      3.times do
        waiters.ready_one do |event|
          case called += 1
          when 1 then event.should eq(pointerof(event1))
          when 2 then event.should eq(pointerof(event2))
          when 3 then event.should eq(pointerof(event3))
          end
          true
        end
      end
      called.should eq(3)
      waiters.@ready.should be_false

      waiters.ready_one do
        called += 1
        true
      end
      called.should eq(3)
      waiters.@ready.should be_true
    end

    it "dequeues events until the block returns true" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      event1 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event2 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event3 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      called = 0

      waiters.add(pointerof(event1))
      waiters.add(pointerof(event2))
      waiters.add(pointerof(event3))

      waiters.ready_one do |event|
        (called += 1) == 2
      end
      called.should eq(2)
      waiters.@ready.should be_false
    end

    it "dequeues events until empty and marks the list as ready" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      event1 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event2 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      called = 0

      waiters.add(pointerof(event1))
      waiters.add(pointerof(event2))

      waiters.ready_one do |event|
        called += 1
        false
      end
      called.should eq(2)
      waiters.@ready.should be_true
    end
  end

  describe "#ready_all" do
    it "marks the list as always ready" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      called = false

      waiters.ready_all { called = true }

      called.should be_false
      waiters.@always_ready.should be_true
    end

    it "dequeues all events" do
      waiters = Crystal::EventLoop::Polling::Waiters.new
      event1 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event2 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      event3 = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      called = 0

      waiters.add(pointerof(event1))
      waiters.add(pointerof(event2))
      waiters.add(pointerof(event3))

      waiters.ready_all do |event|
        case called += 1
        when 1 then event.should eq(pointerof(event1))
        when 2 then event.should eq(pointerof(event2))
        when 3 then event.should eq(pointerof(event3))
        end
      end
      called.should eq(3)
      waiters.@always_ready.should be_true
    end
  end
end
