class Crystal::Evented::FiberEvent
  include Crystal::EventLoop::Event

  def initialize(fiber : Fiber, type : Evented::Event::Type)
    @event = Evented::Event.new(type, fiber)
  end

  # sleep or select timeout
  #
  # NOTE: why can timeout be nil?
  def add(timeout : Time::Span?) : Nil
    return unless timeout

    @event.wake_at = Time.monotonic + timeout
    Crystal::EventLoop.current.add_timer(pointerof(@event))
  end

  # select timeout has been cancelled
  def delete : Nil
    return unless @event.wake_at?

    @event.wake_at = nil
    Crystal::EventLoop.current.delete_timer(pointerof(@event))
  end

  # fiber died
  def free : Nil
    delete
  end

  # the timer triggered (already dequeued from eventloop)
  def clear : Nil
    @event.wake_at = nil
  end
end
