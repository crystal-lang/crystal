class Crystal::Evented::FiberEvent
  include Crystal::EventLoop::Event

  @event_loop : Crystal::EventLoop?

  def initialize(fiber : Fiber, type : Evented::Event::Type)
    @event = Evented::Event.new(type, -1, fiber)
  end

  # sleep or select timeout
  #
  # FIXME: why can timeout be nil?
  def add(timeout : Time::Span?) : Nil
    return unless timeout

    @event.time = Time.monotonic + timeout
    (@event_loop = Crystal::EventLoop.current).enqueue(pointerof(@event))
  end

  # select timeout has been cancelled
  def delete : Nil
    return unless el = @event_loop
    @event_loop = nil
    el.as(Crystal::Evented::EventLoop).dequeue(pointerof(@event))
  end

  # fiber died
  def free : Nil
    delete
  end

  # the timer triggered: no need to dequeue it from the eventloop anymore
  def clear : Nil
    @event_loop = nil
  end
end
