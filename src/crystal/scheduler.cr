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
    {% if flag?(:preview_mt) %}
      ensure_single_resume(fiber)
      GC.lock_read
    {% else %}
      GC.set_stackbottom(fiber.@stack_bottom)
    {% end %}

    current, @current = @current, fiber
    Fiber.swapcontext(pointerof(current.@context), pointerof(fiber.@context))

    {% if flag?(:preview_mt) %}
      GC.unlock_read
    {% end %}
  end

  private def validate_resumable(fiber)
    return if fiber.resumable?

    if fiber.dead?
      fatal_resume_error(fiber, "tried to resume a dead fiber")
    else
      fatal_resume_error(fiber, "can't resume a running fiber")
    end
  end

  private def ensure_single_resume(fiber)
    # Set the current thread as the running thread of *fiber*,
    # but only if *fiber.@current_thread* is effectively *nil*
    if fiber.@current_thread.compare_and_set(nil, Thread.current).last
      # the current fiber will leave the current thread shortly
      # although it's not resumable yet we need to clear
      # *@current.@current_thread* for a future `Scheduler.resume(@current)`
      @current.@current_thread.set(nil)
    else
      fatal_resume_error(fiber, "tried to resume the same fiber multiple times")
    end
  end

  private def fatal_resume_error(fiber, message)
    LibC.dprintf 2, "\nFATAL: #{message}: #{fiber}\n"
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
