require "./event_loop"
require "thread"

class Thread
  # :nodoc:
  def scheduler
    @scheduler ||= Crystal::Scheduler.new
  end
end

# :nodoc:
class Crystal::Scheduler
  def self.reschedule : Nil
    Thread.current.scheduler.reschedule
  end

  def self.enqueue(fiber : Fiber) : Nil
    Thread.current.scheduler.enqueue(fiber)
  end

  def self.enqueue(fibers : Enumerable(Fiber)) : Nil
    Thread.current.scheduler.enqueue(fibers)
  end

  def initialize
    @runnables = Deque(Fiber).new
  end

  def reschedule : Nil
    if runnable = @runnables.shift?
      runnable.resume
    else
      Crystal::EventLoop.resume
    end
  end

  def enqueue(fiber : Fiber) : Nil
    @runnables << fiber
  end

  def enqueue(fibers : Enumerable(Fiber)) : Nil
    @runnables.concat fibers
  end
end
