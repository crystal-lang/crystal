module Fiber::ExecutionContext
  # :nodoc:
  class Monitor
    # the monitor thread ticks every 10ms when the process is active; when the
    # process becomes idle, the interval doubles until it reaches the maximum
    # interval where the monitor thread goes to sleep.
    DEFAULT_EVERY              = 10.milliseconds
    INCREASE_PARALLELISM_EVERY = 100.milliseconds
    COLLECT_STACKS_EVERY       = 5.seconds
    MAXIMUM_EVERY              = COLLECT_STACKS_EVERY * 2

    @thread : Thread?

    {% if compare_versions(Crystal::VERSION, "1.4.0") < 0 %}
      @every : Time::Span
      @collect_stacks_next : Time::Instant
      @increase_parallelism_next : Time::Instant
    {% end %}

    def initialize(@every = DEFAULT_EVERY)
      @collect_stacks_next = Crystal::System::Time.instant + COLLECT_STACKS_EVERY
      @increase_parallelism_next = Crystal::System::Time.instant + INCREASE_PARALLELISM_EVERY

      @busy = true
      @signaled = Atomic(Bool).new(false)

      # OPTIMIZE: use futex or alike for a lock-free wait/wake
      @mutex = Thread::Mutex.new
      @condition = Thread::ConditionVariable.new

      @thread = Thread.new(name: "SYSMON") { run_loop }
    end

    def wake : Nil
      return if @signaled.get(:relaxed)

      @mutex.synchronize do
        unless @signaled.swap(true, :relaxed)
          @condition.signal
        end
      end
    end

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
      every do |now, last_iteration|
        transfer_schedulers_blocked_on_syscall
        increase_parallelism(now)
        @busy ||= !system_idle?

        # reset last iteration flag if we notice any activity
        last_iteration = false if @busy
        collect_stacks(now, last_iteration)
      end
    end

    # Executes the block at exact intervals (depending on the OS scheduler
    # precision and overall OS load), without counting the time to execute the
    # block.
    private def every(&)
      every = @every
      start = Crystal::System::Time.instant
      last_iteration = false

      loop do
        @mutex.synchronize do
          if @busy || @signaled.lazy_get
            # noticed activity or awoken: reset to default every
            every = @every
            last_iteration = false
          else
            # idle and not signaled: double the current delay
            every *= 2
          end

          if last_iteration
            # we reached the maximum interval: go to sleep
            Crystal.trace :thread, "sysmon.sleep", busy: @busy, signaled: @signaled.lazy_get
            @condition.wait(@mutex)
            last_iteration = false
          else
            # regular interval or drifting away; calculate remaining time for
            # more steady wakeups (minimize exponential delays)
            timeout = (start + every - Crystal::System::Time.instant).clamp(Time::Span.zero..)
            Crystal.trace :thread, "sysmon.wait", timeout: timeout.to_nanoseconds, busy: @busy, signaled: @signaled.lazy_get

            @condition.wait(@mutex, timeout) do
              last_iteration = (every * 2) > MAXIMUM_EVERY
            end
          end

          # reset to default every after wakeup
          if @signaled.lazy_get
            @signaled.lazy_set(false)
            every = @every
          end
        end

        @busy = false
        start = Crystal::System::Time.instant
        yield(start, last_iteration)
      rescue exception
        Crystal.print_error_buffered("BUG: %s#every crashed", self.class.name, exception: exception)
      end
    end

    private def system_idle? : Bool
      ExecutionContext.each do |execution_context|
        execution_context.each_scheduler do |scheduler|
          return false unless scheduler.idle?
        end
      end
      true
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

          @busy = true

          pool = ExecutionContext.thread_pool
          pool.detach(scheduler.thread)
          pool.checkout(scheduler)
        end
      end
    end

    # Iterates parallel execution contexts and increases their parallelism when
    # there are pending fibers waiting to run.
    #
    # At most, the parallelism will double on each iteration. This is to avoid
    # waking too many schedulers at once which can waste resources to wake the
    # schedulers that might just fight to dequeue/steal fibers instead of
    # running them.
    private def increase_parallelism(now) : Nil
      return unless @increase_parallelism_next <= now
      @increase_parallelism_next = now + INCREASE_PARALLELISM_EVERY

      ExecutionContext.each do |execution_context|
        next unless execution_context.is_a?(Parallel)
        next if (capacity = execution_context.capacity) == 1

        # how many schedulers are active (running, spinning)?
        active = execution_context.size
        next if active == 0

        # how many schedulers can be woken?
        available = capacity - active
        next if available == 0

        # don't wake more schedulers than currently active (scale active
        # parallelism to a factor of 2 max)
        available = active if available > active

        # fibers from the global queue are divided evenly across active
        # schedulers, so wake as many schedulers as needed
        count = execution_context.@global_queue.size

        if count < available
          # split work: wake one scheduler for every scheduler with fibers in
          # its local queue
          execution_context.each_scheduler do |scheduler|
            count += 1 unless scheduler.@runnables.empty?
            break if count == available
          end
        else
          count = available
        end

        if count > 0
          @busy = true
          execution_context.wake_scheduler(count)
        end
      end
    end

    # Iterates each execution context and collects unused fiber stacks.
    #
    # OPTIMIZE: should maybe happen during GC collections (?)
    private def collect_stacks(now, last_iteration)
      return unless @collect_stacks_next <= now || last_iteration
      @collect_stacks_next = now + COLLECT_STACKS_EVERY

      Crystal.trace :thread, "collect_stacks" do
        if last_iteration
          ExecutionContext.each(&.stack_pool?.try(&.clear))
        else
          ExecutionContext.each(&.stack_pool?.try(&.collect))
        end
      end
    end
  end
end
