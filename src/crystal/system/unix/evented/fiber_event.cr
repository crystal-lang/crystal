class Crystal::Evented::FiberEvent
  include Crystal::EventLoop::Event

  def initialize(@event_loop : Evented::EventLoop, fiber : Fiber, type : Evented::Event::Type)
    @event = Evented::Event.new(type, -1, fiber)
  end

  # sleep or select timeout
  #
  # FIXME: why can timeout be nil?
  def add(timeout : Time::Span?) : Nil
    return unless timeout

    @event.time = Time.monotonic + timeout
    @event_loop.enqueue(pointerof(@event))
  end

  # select timeout has been cancelled
  def delete : Nil
    @event_loop.dequeue(pointerof(@event))
  end

  # fiber died
  def free : Nil
    @event_loop.dequeue(pointerof(@event))
  end
end
