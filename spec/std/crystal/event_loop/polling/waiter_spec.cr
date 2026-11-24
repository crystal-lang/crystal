{% skip_file unless Crystal::EventLoop.has_constant?(:Polling) %}

require "spec"

describe Crystal::EventLoop::Polling::Waiter do
  describe "#add" do
    it "sets the event" do
      waiter = Crystal::EventLoop::Polling::Waiter.new

      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      ret = waiter.add(pointerof(event))
      ret.should be_true
    end

    it "rejects a second waiter without replacing the first" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      other = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      waiter.add(pointerof(event))

      expect_raises(Exception, "BUG: polling operation already has a waiter") do
        waiter.add(pointerof(other))
      end
      waiter.delete(pointerof(other))
      waiter.empty?.should be_false
      waiter.ready_one { |pending| pending.should eq(pointerof(event)); true }
    end

    it "doesn't set the event when ready (race condition)" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      waiter.ready_one { true }

      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      ret = waiter.add(pointerof(event))
      ret.should be_false
      waiter.@ready.should be_false
    end

    it "doesn't set the event when always ready" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      waiter.ready_all { }

      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      ret = waiter.add(pointerof(event))
      ret.should be_false
      waiter.@always_ready.should be_true
    end
  end

  describe "#delete" do
    it "unsets the event" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)

      waiter.add(pointerof(event))
      waiter.delete(pointerof(event))

      called = false
      waiter.ready_one { called = true }
      called.should be_false
    end

    it "does nothing when there's no event" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      waiter.delete(pointerof(event))
    end
  end

  describe "#ready_one" do
    it "marks as ready when empty (race condition)" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      called = false

      waiter.ready_one { called = true }

      called.should be_false
      waiter.@ready.should be_true
    end

    it "detaches the event before completing it" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      waiter.add(pointerof(event))

      called = false
      waiter.ready_one do |pending|
        pending.should eq(pointerof(event))
        waiter.empty?.should be_true
        called = true
      end
      called.should be_true
      waiter.@ready.should be_false
    end

    it "preserves readiness when the timer owns completion" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      waiter.add(pointerof(event))

      waiter.ready_one { false }
      waiter.empty?.should be_true
      waiter.add(pointerof(event)).should be_false
      waiter.add(pointerof(event)).should be_true
    end
  end

  describe "#ready_all" do
    it "marks as always ready" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      called = false

      waiter.ready_all { called = true }

      called.should be_false
      waiter.@always_ready.should be_true
    end

    it "detaches the event and keeps terminal readiness" do
      waiter = Crystal::EventLoop::Polling::Waiter.new
      event = Crystal::EventLoop::Polling::Event.new(:io_read, Fiber.current)
      waiter.add(pointerof(event))

      called = false
      waiter.ready_all do |pending|
        pending.should eq(pointerof(event))
        waiter.empty?.should be_true
        called = true
      end
      called.should be_true
      2.times { waiter.add(pointerof(event)).should be_false }
    end
  end
end
