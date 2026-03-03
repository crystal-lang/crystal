module Fiber::ExecutionContext
  # :nodoc:
  module Scheduler
    @[AlwaysInline]
    def self.current : Scheduler
      Thread.current.scheduler
    end

    @[AlwaysInline]
    def self.current? : Scheduler?
      Thread.current.scheduler?
    end

    protected abstract def thread : Thread
    protected abstract def execution_context : ExecutionContext

    # Instantiates a fiber and enqueues it into the scheduler's local queue.
    def spawn(*, name : String? = nil, &block : ->) : Fiber
      fiber = Fiber.new(name, execution_context, &block)
      enqueue(fiber)
      fiber
    end

    # Legacy support for the *same_thread* argument. Each execution context may
    # decide to support it or not (e.g. a single threaded context can accept it).
    abstract def spawn(*, name : String? = nil, same_thread : Bool, &block : ->) : Fiber

    # Suspends the current fiber and resumes *fiber* instead.
    # The current fiber will never be resumed; you're responsible to reenqueue it.
    #
    # Unsafe. Must only be called on `ExecutionContext.current`. Prefer
    # `ExecutionContext.enqueue` instead.
    protected abstract def enqueue(fiber : Fiber) : Nil

    # Suspends the execution of the current fiber and resumes the next runnable
    # fiber.
    #
    # Unsafe. Must only be called on `ExecutionContext.current`. Prefer
    # `ExecutionContext.reschedule` instead.
    protected abstract def reschedule : Nil

    # Suspends the execution of the current fiber and resumes *fiber*.
    #
    # The current fiber will never be resumed; you're responsible to reenqueue
    # it.
    #
    # Unsafe. Must only be called on `ExecutionContext.current`. Prefer
    # `ExecutionContext.resume` instead.
    protected abstract def resume(fiber : Fiber) : Nil

    # Switches the thread from running the current fiber to run *fiber* instead.
    #
    # Handles thread safety around fiber stacks by locking the GC, so it won't
    # start a GC collection while we're switching context.
    #
    # Unsafe. Must only be called by the current scheduler. The caller must
    # ensure that the fiber indeed belongs to the current execution context and
    # that the fiber can indeed be resumed.
    #
    # WARNING: after switching context you can't trust *self* anymore (it is the
    # scheduler that resumed *fiber* which may not be the one that suspended
    # *fiber*) or instance variables; local variables however are the ones from
    # before swapping context.
    protected def swapcontext(fiber : Fiber) : Nil
      current_fiber = thread.current_fiber

      GC.lock_read
      thread.current_fiber = fiber
      Crystal::FiberLocalStorage.fls = fiber.fls
      Fiber.swapcontext(pointerof(current_fiber.@context), pointerof(fiber.@context))
      GC.unlock_read
    end

    # Returns the current status of the scheduler. For example `"running"`,
    # `"event-loop"` or `"parked"`.
    abstract def status : String

    # :nodoc:
    SYSCALL_FLAG = 1_u32

    # :nodoc:
    # use to increment the counter to avoid ABA issues
    SYSCALL_INCREMENT = 2_u32

    @syscall = Atomic(UInt32).new(0_u32)

    # :nodoc:
    #
    # Marks the current scheduler as doing a syscall that may block the current
    # thread for an unknown time. This allows the monitor thread to move the
    # scheduler to another thread, without waiting for the syscall to complete.
    #
    # When the syscall eventually completes, the thread will check if the
    # scheduler has been detached and either continue running the current fiber
    # if the scheduler is still attached, or enqueue the current fiber back into
    # its execution context, then returns itself back into the thread pool.
    def syscall(& : -> U) : U forall U
      scheduler = Scheduler.current
      fiber = Fiber.current
      value = scheduler.enter_syscall

      ret = yield

      unless scheduler.leave_syscall?(value)
        # the scheduler has been detached (or is being detached): enqueue the
        # current fiber back into its execution context, and return the thread
        # back into the thread pool
        scheduler.execution_context.external_enqueue(fiber)
        ExecutionContext.thread_pool.checkin
      end

      # the scheduler wasn't detached, or the fiber has been resume: we can
      # continue normally
      ret
    end

    protected def enter_syscall : UInt32
      old_value = @syscall.add(SYSCALL_FLAG | SYSCALL_INCREMENT, :acquire_release)
      old_value + SYSCALL_FLAG | SYSCALL_INCREMENT
    end

    protected def leave_syscall?(value : UInt32) : Bool
      new_value = (value & ~SYSCALL_FLAG) &+ SYSCALL_INCREMENT
      _, success = @syscall.compare_and_set(value, new_value, :acquire_release, :relaxed)
      success
    end

    protected def detach_syscall? : Bool
      value = @syscall.get(:relaxed)
      value.bits_set?(SYSCALL_FLAG) && leave_syscall?(value)
    end
  end
end
