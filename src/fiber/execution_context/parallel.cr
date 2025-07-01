require "./global_queue"
require "./parallel/scheduler"

module Fiber::ExecutionContext
  # Parallel execution context.
  #
  # Fibers running in the same context run both concurrently and in parallel to each
  # others, in addition to the other fibers running in other execution contexts.
  #
  # The context internally keeps a number of fiber schedulers, each scheduler
  # being able to start running on a system thread, so multiple schedulers can
  # run in parallel. The fibers are resumable by any scheduler in the context,
  # they can thus move from one system thread to another at any time.
  #
  # The actual parallelism is controlled by the execution context. As the need
  # for parallelism increases, for example more fibers running longer, the more
  # schedulers will start (and thus system threads), as the need decreases, for
  # example not enough fibers, the schedulers will pause themselves and
  # parallelism will decrease.
  #
  # For example: we can start a parallel context to run consumer fibers, while
  # the default context produces values. Because the consumer fibers can run in
  # parallel, we must protect accesses to the shared *value* variable. Running
  # the example without `Atomic#add` would produce a different result every
  # time!
  #
  # ```
  # require "wait_group"
  #
  # consumers = Fiber::ExecutionContext::Parallel.new("consumers", 8)
  # channel = Channel(Int32).new(64)
  # wg = WaitGroup.new(32)
  #
  # result = Atomic.new(0)
  #
  # 32.times do
  #   consumers.spawn do
  #     while value = channel.receive?
  #       result.add(value)
  #     end
  #   ensure
  #     wg.done
  #   end
  # end
  #
  # 1024.times { |i| channel.send(i) }
  # channel.close
  #
  # # wait for all workers to be done
  # wg.wait
  #
  # p result.get # => 523776
  # ```
  class Parallel
    include ExecutionContext

    getter name : String

    @mutex : Thread::Mutex
    @condition : Thread::ConditionVariable
    protected getter global_queue : GlobalQueue

    # :nodoc:
    getter stack_pool : Fiber::StackPool = Fiber::StackPool.new

    # :nodoc:
    getter event_loop : Crystal::EventLoop = Crystal::EventLoop.create
    @event_loop_lock = Atomic(Bool).new(false)

    @parked = Atomic(Int32).new(0)
    @spinning = Atomic(Int32).new(0)

    # :nodoc:
    protected def self.default(maximum : Int32) : self
      new("DEFAULT", maximum, hijack: true)
    end

    # Starts a context with a *maximum* parallelism. The context starts with an
    # initial parallelism of zero. It will grow to one when a fiber is spawned,
    # then the actual parallelism will keep increasing and decreasing as needed,
    # but will never go past the configured *maximum*.
    def self.new(name : String, maximum : Int32) : self
      new(name, maximum, hijack: false)
    end

    @[Deprecated("Use Fiber::ExecutionContext::Parallel.new(String, Int32) instead.")]
    def self.new(name : String, size : Range(Nil, Int32)) : self
      new(name, size.exclusive? ? size.end - 1 : size.end, hijack: false)
    end

    @[Deprecated("Use Fiber::ExecutionContext::Parallel.new(String, Int32) instead.")]
    def self.new(name : String, size : Range(Int32, Int32)) : self
      raise ArgumentError.new("invalid range") if size.begin > size.end
      new(name, size.exclusive? ? size.end - 1 : size.end, hijack: false)
    end

    protected def initialize(@name : String, @capacity : Int32, hijack : Bool)
      raise ArgumentError.new("Parallelism can't be less than one.") if @capacity < 1

      @mutex = Thread::Mutex.new
      @condition = Thread::ConditionVariable.new

      @global_queue = GlobalQueue.new(@mutex)
      @schedulers = Array(Scheduler).new(capacity)
      @threads = Array(Thread).new(capacity)

      @rng = Random::PCG32.new

      start_schedulers(capacity)
      @threads << hijack_current_thread(@schedulers.first) if hijack

      ExecutionContext.execution_contexts.push(self)
    end

    # The number of threads that have been started.
    def size : Int32
      @threads.size
    end

    # The maximum number of threads that can be started.
    def capacity : Int32
      @schedulers.size
    end

    # :nodoc:
    def stack_pool? : Fiber::StackPool?
      @stack_pool
    end

    # Starts all schedulers at once.
    #
    # We could lazily initialize them as needed, like we do for threads, which
    # would be safe as long as we only mutate when the mutex is locked... but
    # unlike @threads, we do iterate the schedulers in #steal without locking
    # the mutex (for obvious reasons) and there are no guarantees that the new
    # schedulers.@size will be written after the scheduler has been written to
    # the array's buffer.
    #
    # OPTIMIZE: consider storing schedulers to an array-like object that would
    # use an atomic/fence to make sure that @size can only be incremented
    # *after* the value has been written to @buffer.
    private def start_schedulers(capacity)
      capacity.times do |index|
        @schedulers << Scheduler.new(self, "#{@name}-#{index}")
      end
    end

    # Attaches *scheduler* to the current `Thread`, usually the process' main
    # thread. Starts a `Fiber` to run the scheduler loop.
    private def hijack_current_thread(scheduler) : Thread
      thread = Thread.current
      thread.internal_name = scheduler.name
      thread.execution_context = self
      thread.scheduler = scheduler

      scheduler.thread = thread
      scheduler.main_fiber = Fiber.new("#{scheduler.name}:loop", self) do
        scheduler.run_loop
      end

      thread
    end

    # Starts a new `Thread` and attaches *scheduler*. Runs the scheduler loop
    # directly in the thread's main `Fiber`.
    private def start_thread(scheduler) : Thread
      Thread.new(name: scheduler.name) do |thread|
        thread.execution_context = self
        thread.scheduler = scheduler

        scheduler.thread = thread
        scheduler.main_fiber = thread.main_fiber
        scheduler.main_fiber.name = "#{scheduler.name}:loop"
        scheduler.run_loop
      end
    end

    # Resizes the context to the new *maximum* parallelism.
    #
    # The new *maximum* can grow, in which case more schedulers are created to
    # eventually increase the parallelism.
    #
    # The new *maximum* can also shrink, in which case the overflow schedulers
    # are removed and told to shutdown immediately. The actual shutdown is
    # cooperative, so running schedulers won't stop until their current fiber
    # tries to switch to another fiber.
    def resize(maximum : Int32) : Nil
      maximum = maximum.clamp(1..) # FIXME: raise if maximum < 1
      removed_schedulers = nil

      @mutex.synchronize do
        # can run in parallel to #steal that dereferences @schedulers (once)
        # without locking the mutex, so we dup the schedulers, mutate the copy,
        # and eventually assign the copy as @schedulers; this way #steal can
        # safely access the array (never mutated).
        new_schedulers = nil
        new_capacity = maximum
        old_threads = @threads
        old_schedulers = @schedulers
        old_capacity = capacity

        if new_capacity > old_capacity
          @schedulers = Array(Scheduler).new(new_capacity) do |index|
            old_schedulers[index]? || Scheduler.new(self, "#{@name}-#{index}")
          end
          threads = Array(Thread).new(new_capacity)
          old_threads.each { |thread| threads << thread }
          @threads = threads
        elsif new_capacity < old_capacity
          # tell the overflow schedulers to shutdown
          removed_schedulers = old_schedulers[new_capacity..]
          removed_schedulers.each(&.shutdown(:now))

          # resize
          @schedulers = old_schedulers[0...new_capacity]
          @threads = old_threads[0...new_capacity]

          # makes sure that the above writes to @schedulers and @threads are
          # executed before continuing (maybe not needed, but let's err on the
          # safe side)
          Atomic.fence(:acquire_release)

          # wakeup all waiting schedulers so they can shutdown
          @condition.broadcast
          @event_loop.interrupt
        end
      end

      return unless removed_schedulers

      # drain the local queues of removed schedulers since they're no longer
      # available for stealing
      removed_schedulers.each do |scheduler|
        scheduler.@runnables.drain
      end
    end

    # :nodoc:
    def spawn(*, name : String? = nil, same_thread : Bool, &block : ->) : Fiber
      raise ArgumentError.new("#{self.class.name}#spawn doesn't support same_thread:true") if same_thread
      self.spawn(name: name, &block)
    end

    # :nodoc:
    def enqueue(fiber : Fiber) : Nil
      if ExecutionContext.current? == self
        # local enqueue: push to local queue of current scheduler
        ExecutionContext::Scheduler.current.enqueue(fiber)
      else
        # cross context: push to global queue
        Crystal.trace :sched, "enqueue", fiber: fiber, to_context: self
        @global_queue.push(fiber)
        wake_scheduler
      end
    end

    # Picks a scheduler at random then iterates all schedulers to try to steal
    # fibers from.
    protected def steal(& : Scheduler ->) : Nil
      return if capacity == 1

      schedulers = @schedulers
      i = @rng.next_int
      n = schedulers.size

      n.times do |j|
        if scheduler = schedulers[(i &+ j) % n]?
          yield scheduler
        end
      end
    end

    protected def park_thread(&) : Fiber?
      @mutex.synchronize do
        # avoid races by checking queues again
        if fiber = yield
          return fiber
        end

        Crystal.trace :sched, "park"
        @parked.add(1, :acquire_release)

        @condition.wait(@mutex)

        # we don't decrement @parked because #wake_scheduler did
        Crystal.trace :sched, "wakeup"
      end

      nil
    end

    # This method always runs in parallel!
    #
    # This can be called from any thread in the context but can also be called
    # from external execution contexts, in which case the context may have its
    # last thread about to park itself, and we must prevent the last thread from
    # parking when there is a parallel cross context enqueue!
    #
    # OPTIMIZE: instead of blindly spending time (blocking progress on the
    # current thread) to unpark a thread / start a new thread we could move the
    # responsibility to an external observer to increase parallelism in a MT
    # context when it detects pending work.
    protected def wake_scheduler : Nil
      # another thread is spinning: nothing to do (it shall notice the enqueue)
      if @spinning.get(:relaxed) > 0
        return
      end

      # interrupt a thread waiting on the event loop
      if @event_loop_lock.get(:relaxed)
        @event_loop.interrupt
        return
      end

      # we can check @parked without locking the mutex because we can't push to
      # the global queue _and_ park the thread at the same time, so either the
      # thread is already parked (and we must awake it) or it noticed (or will
      # notice) the fiber in the global queue;
      #
      # we still rely on an atomic to make sure the actual value is visible by
      # the current thread
      if @parked.get(:acquire) > 0
        @mutex.synchronize do
          # avoid race conditions
          return if @parked.get(:relaxed) == 0
          return if @spinning.get(:relaxed) > 0

          # increase the number of spinning threads _now_ to avoid multiple
          # threads from trying to wakeup multiple threads at the same time
          #
          # we must also decrement the number of parked threads because another
          # thread could lock the mutex and increment @spinning again before the
          # signaled thread is resumed
          spinning = @spinning.add(1, :acquire_release)
          parked = @parked.sub(1, :acquire_release)

          @condition.signal
        end
        return
      end

      # check if we can start another thread; no need for atomics, the values
      # shall be rather stable over time and we check them again inside the
      # mutex
      return if @threads.size >= capacity

      @mutex.synchronize do
        index = @threads.size
        return if index >= capacity # check again

        @threads << start_thread(@schedulers[index])
      end
    end

    # Only one thread is allowed to run the event loop. Yields then returns true
    # if the lock was acquired, otherwise returns false immediately.
    protected def lock_evloop?(&) : Bool
      if @event_loop_lock.swap(true, :acquire) == false
        begin
          yield
        ensure
          @event_loop_lock.set(false, :release)
        end
        true
      else
        false
      end
    end

    @[AlwaysInline]
    def inspect(io : IO) : Nil
      to_s(io)
    end

    def to_s(io : IO) : Nil
      io << "#<" << self.class.name << ":0x"
      object_id.to_s(io, 16)
      io << ' ' << name << '>'
    end
  end

  @[Deprecated("Use Fiber::ExecutionContext::Parallel instead.")]
  alias MultiThreaded = Parallel
end
