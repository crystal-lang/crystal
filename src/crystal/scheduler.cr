require "./event_loop"
require "./scheduler/runnables"
require "fiber"
require "thread"

# :nodoc:
#
# Schedulers are tied to a thread, and must only ever be accessed from within
# this thread.
#
# Only the class methods are public and safe to use. Instance methods are
# protected and must never be called directly.
class Crystal::Scheduler
  def self.current_fiber : Fiber
    Thread.current.scheduler.@current
  end

  def self.enqueue(fiber : Fiber) : Nil
    Thread.current.scheduler.enqueue(fiber)
  end

  def self.enqueue(fibers : Enumerable(Fiber)) : Nil
    Thread.current.scheduler.enqueue(fibers)
  end

  def self.reschedule : Nil
    Thread.current.scheduler.reschedule
  end

  def self.resume(fiber : Fiber) : Nil
    Thread.current.scheduler.resume(fiber)
  end

  def self.sleep(time : Time::Span) : Nil
    Thread.current.scheduler.sleep(time)
  end

  def self.yield : Nil
    Thread.current.scheduler.yield
  end

  def self.yield(fiber : Fiber) : Nil
    Thread.current.scheduler.yield(fiber)
  end

  # :nodoc:
  def initialize(@main : Fiber)
    @current = @main
    @runnables = Runnables.new
  end

  protected def enqueue(fiber : Fiber) : Nil
    @runnables.push(fiber)
  end

  protected def enqueue(fibers : Enumerable(Fiber)) : Nil
    fibers.each do |fiber|
      @runnables.push(fiber)
    end
  end

  protected def resume(fiber : Fiber) : Nil
    spin_until_resumable(fiber)
    current, @current = @current, fiber
    GC.stack_bottom = fiber.@stack_bottom
    Fiber.swapcontext(pointerof(current.@context), pointerof(fiber.@context))
  end

  private def spin_until_resumable(fiber)
    # 1. 1st attempt will always succeed with a single thread (unless the fiber
    #    is dead):
    until fiber.resumable?
      # 2. constant-time busy-loop, to avoid an expensive thread context switch:
      #    relies on a magic number, but anything higher don't seem to improve
      #    performance (on x86_64 at least):
      99.times do
        return if fiber.resumable?
        raise Fiber::DeadFiberError.new("tried to resume a dead fiber", fiber) if fiber.dead?
      end

      # 3. give up, yield CPU time to another thread (avoid contention):
      Thread.yield
    end
  end

  protected def reschedule : Nil
    if fiber = @runnables.pop?
      resume(fiber)
    else
      Crystal::EventLoop.resume
    end
  end

  protected def sleep(time : Time::Span) : Nil
    @current.resume_event.add(time)
    reschedule
  end

  protected def yield : Nil
    sleep(0.seconds)
  end
end
