class Crystal::EventLoop::Polling::FiberEvent
  include Crystal::EventLoop::Event

  def initialize(type : Event::Type, fiber : Fiber)
    @event = Event.new(type, fiber)
  end

  # sleep or select timeout
  def add(timeout : Time::Span) : Nil
    seconds, nanoseconds = System::Time.monotonic
    now = Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
    @event.wake_at = now + timeout
    EventLoop.current.add_timer(pointerof(@event))
  end

  # select timeout has been cancelled
  def delete : Nil
    return unless @event.wake_at?

    EventLoop.current.delete_timer(pointerof(@event))
    clear
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
