module Fiber::ExecutionContext
  # :nodoc:
  class Monitor
    DEFAULT_EVERY        = 10.milliseconds
    COLLECT_STACKS_EVERY = 5.seconds

    @thread : Thread?

    def initialize(@every = DEFAULT_EVERY)
      @collect_stacks_next = Crystal::System::Time.instant + COLLECT_STACKS_EVERY
      @thread = Thread.new(name: "SYSMON") { run_loop }
    end

    # TODO: slow parallelism (MT): instead of actively trying to wakeup, which
    # can be expensive and a source of contention, leading to waste more time
    # than running the enqueued fiber(s) directly, the monitor thread could
    # check the queues of MT schedulers every some milliseconds and decide to
    # start or wake threads.
    #
    # TODO: maybe yield (ST/MT): detect schedulers that have been stuck running
    # the same fiber since the previous iteration (check current fiber &
    # scheduler tick to avoid ABA issues), then mark the fiber to trigger a
    # cooperative yield, for example, `Fiber.maybe_yield` could be called at
    # potential cancellation points that would otherwise not need to block now
    # (IO, mutexes, schedulers, manually called in loops, ...); this could lead
    # fiber execution time be more fair, and we could also warn when a fiber has
    # been asked to yield but still hasn't after N iterations.
    #
    # TODO: event loop starvation: if an execution context didn't have the
    # opportunity to run its event-loop since N iterations, then the monitor
    # thread could run it; it would avoid a set of fibers to always resume
    # themselves at the expense of pending events.
    #
    # TODO: run GC collections on "low" application activity? when we don't
    # allocate the GC won't try to collect memory by itself, which after a peak
    # usage can lead to keep memory allocated when it could be released to the
    # OS.
    private def run_loop : Nil
      every do |now|
        transfer_schedulers_blocked_on_syscall
        collect_stacks(now)
      end
    end

    # Executes the block at exact intervals (depending on the OS scheduler
    # precision and overall OS load), without counting the time to execute the
    # block.
    private def every(&)
      remaining = @every

      loop do
        Thread.sleep(remaining)

        start = Crystal::System::Time.instant
        yield(start)
        stop = Crystal::System::Time.instant

        # calculate remaining time for more steady wakeups (minimize exponential
        # delays)
        remaining = (start + @every - stop).clamp(Time::Span.zero..)
      rescue exception
        Crystal.print_error_buffered("BUG: %s#every crashed", self.class.name, exception: exception)
      end
    end

    # Iterates each ExecutionContext::Scheduler and transfers the Scheduler for
    # any Thread currently blocked on a syscall.
    #
    # OPTIMIZE: a scheduler in a MT context might not need to be transferred if
    # its queue is empty and another scheduler in the context is blocked on the
    # event loop.
    private def transfer_schedulers_blocked_on_syscall : Nil
      ExecutionContext.each do |execution_context|
        execution_context.each_scheduler do |scheduler|
          next unless scheduler.detach_syscall?

          Crystal.trace :sched, "reassociate",
            scheduler: scheduler,
            syscall: scheduler.thread.current_fiber

          pool = ExecutionContext.thread_pool
          pool.detach(scheduler.thread)
          pool.checkout(scheduler)
        end
      end
    end

    # Iterates each execution context and collects unused fiber stacks.
    #
    # OPTIMIZE: should maybe happen during GC collections (?)
    private def collect_stacks(now)
      return unless @collect_stacks_next <= now
      @collect_stacks_next = now + COLLECT_STACKS_EVERY

      Crystal.trace :sched, "collect_stacks" do
        ExecutionContext.each(&.stack_pool?.try(&.collect))
      end
    end
  end
end
