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
  @@mutex = uninitialized Thread::Mutex
  @@all_runnables = uninitialized Array(Runnables)

  def self.init
    @@mutex = Thread::Mutex.new
    @@all_runnables = Array(Runnables).new(Crystal::NPROCS + 1)
    # allocate the main scheduler:
    Thread.current.scheduler
  end

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
    @rng = Random::PCG32.new
    @@mutex.synchronize { @@all_runnables << @runnables }
  end

  # :nodoc:
  #
  # The scheduler's main loop. Follows the algorithms from the "Scheduling
  # Multithreaded Computations by Work Stealing" (2001) paper.
  #
  # The main loop runs on the thread's main stack, and first tries to dequeue
  # and resume a fiber from its internal runnables queue.
  #
  # Once the queue is emptied, the scheduler immediately resumes its main loop,
  # and becomes a thief that will repeat the following actions until it gets a
  # runnable fiber that it can resume:
  #
  # 1. passes CPU time to another thread, allowing other threads to progress;
  # 2. tries to steal a fiber from another random scheduler;
  # 3. executes the event loop to try and fill its internal queue.
  #
  # TODO: loop a limited number of time and eventually park the thread to avoid
  #       burning CPU time.
  def start : Nil
    # always process the internal runnables queue on startup:
    if fiber = @runnables.pop?
      resume(fiber)
    end

    # the runnables queue is now empty

    while Crystal.running?
      # 1. yield CPU time to another thread
      Thread.yield

      # 2. try to steal a runnable fiber from a random scheduler:
      fiber = steal_once

      unless fiber
        # 3. process the event loop to fill the runnables queue if any events
        #    are pending, but don't block, since it would prevent this thread
        #    from stealing fibers (or resuming a yielded fiber), and block other
        #    threads, too:
        Crystal::EventLoop.run_nonblock

        # try to dequeue a fiber from the internal runnables queue:
        fiber = @runnables.pop?
      end

      if fiber
        # success: we now have a runnable fiber (dequeued, stolen or ready):
        resume(fiber)

        # the runnables queue is now empty (again)
      end
    end
  end

  protected def steal_once : Fiber?
    runnables = @@all_runnables.sample(@rng)
    runnables.shift? unless runnables == @runnables
  end

  protected def enqueue(fiber : Fiber) : Nil
    @runnables.push(fiber)
    # TODO: wakeup a parked thread (if any)
  end

  protected def enqueue(fibers : Enumerable(Fiber)) : Nil
    fibers.each do |fiber|
      @runnables.push(fiber)
    end
    # TODO: wakeup parked threads (if any)
  end

  protected def resume(fiber : Fiber) : Nil
    # a fiber can be enqueued before saving its context, which means there is a
    # time window for a scheduler to steal and try to resume a fiber before its
    # context has been fully saved, so we wait:
    spin_until_resumable(fiber)

    {% unless flag?(:gc_none) %}
      # disable GC suspend signal for this thread, so it won't be interrupted
      # while it's swapping context, which would leave the thread in an invalid
      # state (e.g. @current points to the new fiber, but the current stack
      # pointer still points to the old fiber stack) which would lead
      # GC.before_collect to report an invalid stack (mismatched stack bottom &
      # stack pointer) and... crash GC when it will scan the stack.
      GC.block_suspend_signal
    {% end %}

    # replace references:
    current, @current = @current, fiber

    # swap the execution context:
    Fiber.swapcontext(pointerof(current.@context), pointerof(fiber.@context))

    {% unless flag?(:gc_none) %}
      # context was fully swapped, we can reenable the GC suspend signal:
      GC.unblock_suspend_signal
    {% end %}
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

  # Suspends execution of `@current` by saving its context, and resumes another
  # fiber. `@current` is never enqueued and must be manually resumed by another
  # main (event loop, explicit call the `#resume` or `#enqueue`, ...).
  protected def reschedule : Nil
    # try to dequeue the next fiber from the internal runnables queue:
    fiber = @runnables.pop?

    # if the queue was empty, resume the main fiber to resume the scheduler's
    # stealing loop; this allows to save the context of the current fiber, so it
    # can be resumed by another thread without delay (even if the current thread
    # blocks), or even by the same thread if we end up resuming the current
    # fiber:
    fiber ||= @main

    # swap to the new context:
    resume(fiber)
  end

  protected def sleep(time : Time::Span) : Nil
    @current.resume_event.add(time)
    reschedule
  end

  # Very similar to `#reschedule` but enqueues `@current` before switching
  # contexts.
  #
  # Takes care to dequeue a fiber from the runnables queue before `@current` is
  # enqueued, because of the runnables queue algorithm where the scheduler will
  # push/pop from the bottom of the queue —a shift from the top of the queue is
  # reserved for stealing a fiber from another scheduler queue.
  protected def yield : Nil
    # try to dequeue the next fiber from the internal runnables queue:
    fiber = @runnables.pop?

    # if the queue was empty, resume the main fiber to resume the scheduler's
    # stealing loop; this allows to save the context of the current fiber, so it
    # can be resumed by another thread without delay (even if the current thread
    # blocks), or even by the same thread if we end up resuming the current
    # fiber:
    fiber ||= @main

    # enqueue the current fiber, so it can be resumed later or stolen & resumed
    # by another scheduler:
    enqueue(@current)

    # swap to the new context:
    resume(fiber)
  end

  protected def yield(fiber : Fiber) : Nil
    enqueue(@current)
    resume(fiber)
  end
end
