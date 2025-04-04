class Crystal::EventLoop::IoUring::FiberEvent
  include Crystal::EventLoop::Event

  def initialize(type : Event::Type, fiber : Fiber)
    # assert(type.select_timeout?)
    @event = Event.new(type, fiber)
  end

  def add(timeout : Time::Span) : Nil
    @event.timeout = timeout
    EventLoop.current.as(IoUring).add_timer(pointerof(@event))
  end

  # select timeout has been cancelled
  def delete : Nil
    return unless @event.timeout?
    EventLoop.current.as(IoUring).delete_timer(pointerof(@event))
    clear
  end

  # fiber died
  def free : Nil
    delete
  end

  # the timer triggered (already dequeued from eventloop)
  def clear : Nil
    @event.timeout = nil
  end
end
