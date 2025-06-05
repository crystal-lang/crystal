require "./global_queue"
require "./runnables"
require "./scheduler"

module Fiber::ExecutionContext
  # A single-threaded execution context which owns a single thread. It's fully
  # concurrent with limited parallelism.
  #
  # Concurrency is restricted to a single thread. Fibers in the same context
  # will never run in parallel to each other but they may still run in parallel
  # to fibers running in other contexts (i.e. in another thread).
  #
  # Fibers can use simpler and faster synchronization primitives between
  # themselves (no atomics, no thread safety). Communication with fibers in
  # other contexts requires thread-safe primitives.
  #
  # A blocking fiber blocks the entire thread and all other fibers in the
  # context.
  class SingleThreaded
    include ExecutionContext
    include ExecutionContext::Scheduler

    getter name : String

    protected property thread : Thread
    protected getter main_fiber : Fiber

    @mutex : Thread::Mutex
    @global_queue : GlobalQueue
    @runnables : Runnables(256)

    # :nodoc:
    getter stack_pool : Fiber::StackPool = Fiber::StackPool.new

    # :nodoc:
    getter event_loop : Crystal::EventLoop = Crystal::EventLoop.create

    @waiting = Atomic(Bool).new(false)
    @parked = Atomic(Bool).new(false)
    @spinning = Atomic(Bool).new(false)
    @tick : Int32 = 0

    # :nodoc:
    #
    # Starts the default execution context. There can be only one for the whole
    # process. Must be called from the main thread's main fiber; associates the
    # current thread and fiber to the created execution context.
    protected def self.default : self
      Fiber.current.execution_context = new("DEFAULT", hijack: true)
    end

    def self.new(name : String) : self
      new(name, hijack: false)
    end

    protected def initialize(@name : String, hijack : Bool)
      @mutex = Thread::Mutex.new
      @global_queue = GlobalQueue.new(@mutex)
      @runnables = Runnables(256).new(@global_queue)
      @thread = uninitialized Thread
      @main_fiber = uninitialized Thread

      @main_fiber = Fiber.new("#{@name}:loop", self) { run_loop }
      @thread = hijack ? hijack_current_thread : start_thread

      ExecutionContext.execution_contexts.push(self)
    end

    # :nodoc:
    def execution_context : self
      self
    end

    # :nodoc:
    def stack_pool? : Fiber::StackPool?
      @stack_pool
    end

    # Initializes the scheduler on the current thread (usually the process'
    # main thread).
    private def hijack_current_thread : Thread
      thread = Thread.current
      thread.internal_name = @name
      thread.execution_context = self
      thread.scheduler = self
      thread
    end

    # Creates a new thread to initialize the scheduler.
    private def start_thread : Thread
      ExecutionContext.thread_pool.checkout(self)
    end

    protected def each_scheduler(& : Scheduler ->) : Nil
      yield self.as(Scheduler)
    end

    # :nodoc:
    def spawn(*, name : String? = nil, same_thread : Bool, &block : ->) : Fiber
      # whatever the value of same_thread: the fibers will always run on the
      # same thread
      self.spawn(name: name, &block)
    end

    # :nodoc:
    def enqueue(fiber : Fiber) : Nil
      if ExecutionContext.current? == self
        # local enqueue
        Crystal.trace :sched, "enqueue", fiber: fiber
        @runnables.push(fiber)
      else
        # cross context or detached thread enqueue
        Crystal.trace :sched, "enqueue", fiber: fiber, to_context: self
        @global_queue.push(fiber)
        wake_scheduler
      end
    end

    protected def reschedule : Nil
      Crystal.trace :sched, "reschedule"
      if fiber = quick_dequeue?
        resume fiber unless fiber == @thread.current_fiber
      else
        # nothing to do: switch back to the main loop to spin/park
        resume @main_fiber
      end
    end

    # FIXME: duplicates MultiThreaded::Scheduler#resume
    protected def resume(fiber : Fiber) : Nil
      Crystal.trace :sched, "resume", fiber: fiber

      # fibers should always be ready to be resumed in the ST environment,
      # unless SYSMON moved the scheduler to another thread while the fiber was
      # blocked on a syscall; upon return the original thread might have
      # enqueued the fiber, but hasn't swapcontext while this thread already
      # tries to resume it
      attempts = 0

      until fiber.resumable?
        if fiber.dead?
          raise "BUG: tried to resume dead fiber #{fiber} (#{inspect})"
        end
        attempts = Thread.delay(attempts)
      end

      swapcontext(fiber)
    end

    private def quick_dequeue? : Fiber?
      # every once in a while: dequeue from global queue to avoid two fibers
      # constantly respawing each other to completely occupy the local queue
      if (@tick &+= 1) % 61 == 0
        if fiber = @global_queue.pop?
          return fiber
        end
      end

      # try local queue
      if fiber = @runnables.shift?
        return fiber
      end

      # try to refill local queue
      if fiber = @global_queue.grab?(@runnables, divisor: 1)
        return fiber
      end

      # run the event loop to see if any event is activable
      list = Fiber::List.new
      @event_loop.run(pointerof(list), blocking: false)
      return enqueue_many(pointerof(list))
    end

    private def run_loop : Nil
      Crystal.trace :sched, "started"

      loop do
        if fiber = find_next_runnable
          spin_stop if @spinning.get(:relaxed)
          resume fiber
        else
          # the event loop enqueued a fiber (or was interrupted) or the
          # scheduler was unparked: go for the next iteration
        end
      rescue exception
        Crystal.print_error_buffered("BUG: %s#run_loop [%s] crashed",
          self.class.name, @name, exception: exception)
      end
    end

    private def find_next_runnable : Fiber?
      find_next_runnable do |fiber|
        return fiber if fiber
      end
    end

    private def find_next_runnable(&) : Nil
      list = Fiber::List.new

      # nothing to do: start spinning
      spinning do
        # usually empty but the scheduler may have been transferred to another
        # thread with queued fibers
        yield @runnables.shift?

        yield @global_queue.grab?(@runnables, divisor: 1)

        @event_loop.run(pointerof(list), blocking: false)
        yield enqueue_many(pointerof(list))
      end

      # block on the event loop, waiting for pending event(s) to activate
      waiting do
        # there is a time window between stop spinning and start waiting during
        # which another context can enqueue a fiber, check again before waiting
        # on the event loop to avoid missing a runnable fiber
        yield @global_queue.grab?(@runnables, divisor: 1)

        @event_loop.run(pointerof(list), blocking: true)
        yield enqueue_many(pointerof(list))

        # the event loop was interrupted: restart the run loop
        return
      end
    end

    private def enqueue_many(list : Fiber::List*) : Fiber?
      if fiber = list.value.pop?
        @runnables.bulk_push(list) unless list.value.empty?
        fiber
      end
    end

    private def spinning(&)
      spin_start

      4.times do |attempt|
        Thread.yield unless attempt == 0
        yield
      end

      spin_stop
    end

    private def spin_start : Nil
      @spinning.set(true, :release)
    end

    private def spin_stop : Nil
      @spinning.set(false, :release)
    end

    private def waiting(&)
      @waiting.set(true, :release)
      begin
        yield
      ensure
        @waiting.set(false, :release)
      end
    end

    # This method runs in parallel to the rest of the ST scheduler!
    #
    # This is called from another context _after_ enqueueing into the global
    # queue to try and wakeup the ST thread running in parallel that may be
    # running, spinning or waiting on the event loop.
    private def wake_scheduler : Nil
      if @spinning.get(:acquire)
        return
      end

      if @waiting.get(:acquire)
        @event_loop.interrupt
      end
    end

    def inspect(io : IO) : Nil
      to_s(io)
    end

    def to_s(io : IO) : Nil
      io << "#<" << self.class.name << ":0x"
      object_id.to_s(io, 16)
      io << ' ' << name << '>'
    end

    def status : String
      if @spinning.get(:relaxed)
        "spinning"
      elsif @waiting.get(:relaxed)
        "event-loop"
      elsif @syscall.get(:relaxed).bits_set?(SYSCALL_FLAG)
        "syscall"
      else
        "running"
      end
    end
  end
end
