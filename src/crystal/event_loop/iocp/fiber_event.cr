class Crystal::EventLoop::IOCP::FiberEvent
  include Crystal::EventLoop::Event

  delegate type, wake_at, wake_at?, fiber, timed_out?, to: @timer

  def initialize(type : Timer::Type, fiber : Fiber)
    @timer = Timer.new(type, fiber)
  end

  # io timeout, sleep, or select timeout
  def add(timeout : Time::Span) : Nil
    seconds, nanoseconds = System::Time.monotonic
    now = Time::Span.new(seconds: seconds, nanoseconds: nanoseconds)
    @timer.wake_at = now + timeout
    EventLoop.current.add_timer(pointerof(@timer))
  end

  # select timeout has been cancelled
  def delete : Nil
    return unless @timer.wake_at?
    EventLoop.current.delete_timer(pointerof(@timer))
    clear
  end

  # fiber died
  def free : Nil
    delete
  end

  # the timer triggered (already dequeued from eventloop)
  def clear : Nil
    @timer.wake_at = nil
  end
end
