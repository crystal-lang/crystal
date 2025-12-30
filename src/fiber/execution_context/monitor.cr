module Fiber::ExecutionContext
  # :nodoc:
  class Monitor
    DEFAULT_EVERY = 5.seconds

    @thread : Thread?

    def initialize(@every = DEFAULT_EVERY)
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
        collect_stacks
      end
    end

    # Executes the block at exact intervals (depending on the OS scheduler
    # precision and overall OS load), without counting the time to execute the
    # block.
    private def every(&)
      remaining = @every

      loop do
        Thread.sleep(remaining)
        now = Crystal::System::Time.instant
        yield(now)
        # Cannot use `now.elapsed` here because it calls `::Time.instant` which
        # could be mocked.
        remaining = Crystal::System::Time.instant.duration_since(now) + @every
      rescue exception
        Crystal.print_error_buffered("BUG: %s#every crashed", self.class.name, exception: exception)
      end
    end

    # Iterates each execution context and collects unused fiber stacks.
    #
    # OPTIMIZE: should maybe happen during GC collections (?)
    private def collect_stacks
      Crystal.trace :sched, "collect_stacks" do
        ExecutionContext.each(&.stack_pool?.try(&.collect))
      end
    end
  end
end
