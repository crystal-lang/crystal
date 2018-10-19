require "./event_loop"
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
    @runnables = Deque(Fiber).new
  end

  protected def enqueue(fiber : Fiber) : Nil
    @runnables << fiber
  end

  protected def enqueue(fibers : Enumerable(Fiber)) : Nil
    @runnables.concat fibers
  end

  protected def resume(fiber : Fiber) : Nil
    validate_resumable(fiber)
    current, @current = @current, fiber
    GC.stack_bottom = fiber.@stack_bottom
    Fiber.swapcontext(pointerof(current.@context), pointerof(fiber.@context))
  end

  private def validate_resumable(fiber)
    return if fiber.resumable?

    if fiber.dead?
      LibC.dprintf 2, "\nFATAL: tried to resume a dead fiber: #{fiber}\n"
    else
      LibC.dprintf 2, "\nFATAL: can't resume a running fiber: #{fiber}\n"
    end

    caller.each { |line| LibC.dprintf(2, "  from #{line}\n") }

    exit 1
  end

  protected def reschedule : Nil
    if runnable = @runnables.shift?
      runnable.resume
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

  protected def yield(fiber : Fiber) : Nil
    @current.resume_event.add(0.seconds)
    resume(fiber)
  end
end
