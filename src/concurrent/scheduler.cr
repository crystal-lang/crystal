require "./event_loop"

# :nodoc:
class Scheduler
  @@runnables = Deque(Fiber).new

  def self.reschedule
    if runnable = @@runnables.shift?
      runnable.resume
    else
      EventLoop.resume
    end
    nil
  end

  def self.enqueue(fiber : Fiber)
    @@runnables << fiber
  end

  def self.enqueue(fibers : Enumerable(Fiber))
    @@runnables.concat fibers
  end
end
