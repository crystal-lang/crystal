require "../crystal/event_loop"
require "../crystal/system/thread"
require "../crystal/system/thread_linked_list"
require "../fiber"
require "./stack_pool"
require "./execution_context/*"

{% raise "ERROR: execution contexts require the `preview_mt` compilation flag" unless flag?(:preview_mt) || flag?(:docs) %}
{% raise "ERROR: execution contexts require the `execution_context` compilation flag" unless flag?(:execution_context) || flag?(:docs) %}

# An execution context creates and manages a dedicated pool of 1 or more threads
# where fibers can be executed into. Each context manages the rules to run,
# suspend and swap fibers internally.
#
# EXPERIMENTAL: Execution contexts are an experimental feature, implementing
# [RFC 2](https://github.com/crystal-lang/rfcs/pull/2). It's opt-in and requires
# the compiler flags `-Dpreview_mt -Dexecution_context`.
#
# Applications can create any number of execution contexts in parallel. These
# contexts are isolated but they can communicate with the usual thread-safe
# synchronization primitives (e.g. `Channel`, `Mutex`).
#
# An execution context groups fibers together. Instead of associating a fiber to
# a specific thread, we associate a fiber to an execution context, abstracting
# which thread(s) they actually run on.
#
# When spawning a fiber with `::spawn`, it spawns into the execution context of
# the current fiber. Thus child fibers execute in the same context as their
# parent (unless told otherwise).
#
# Once spawned, a fiber cannot _move_ to another execution context. It always
# resumes in the same execution context.
#
# ## Context types
#
# The standard library provides a number of execution context implementations
# for common use cases.
#
# * `ExecutionContext::SingleThreaded`: Fully concurrent with limited
# parallelism. Fibers run concurrently in a single thread and never in parallel.
# They can use simpler and faster synchronization primitives internally (no
# atomics, no thread safety). Communication with fibers in other contexts
# requires thread-safe primitives. A blocking fiber blocks the entire thread and
# all other fibers in the context.
# * `ExecutionContext::MultiThreaded`: Fully concurrent, fully parallel. Fibers
# running in this context can be resumed by any thread in this context. They run
# concurrently and in parallel to each other, in addition to running in parallel
# to any fibers in other contexts. Schedulers steal work from each other. The
# number of threads can grow and shrink dynamically.
# * `ExecutionContext::Isolated`: Single fiber in a single thread without
# concurrency. This is useful for tasks that can block thread execution for a
# long time (e.g. a GUI main loop, a game loop, or CPU heavy computation). The
# event-loop works normally (when the fiber sleeps, it pauses the thread).
# Communication with fibers in other contexts requires thread-safe primitives.
#
# ## The default execution context
#
# The Crystal runtime starts with a single threaded execution context, available
# in `Fiber::ExecutionContext.default`.
#
# ```
# Fiber::ExecutionContext.default.class # => Fiber::ExecutionContext::SingleThreaded
# ```
#
# NOTE: The single threaded default context is required for backwards
# compatibility. It may change to a multi-threaded default context in the
# future.
@[Experimental]
module Fiber::ExecutionContext
  @@default : ExecutionContext?

  # Returns the default `ExecutionContext` for the process, automatically
  # started when the program started.
  #
  # NOTE: The default context is a `SingleThreaded` context for backwards
  # compatibility reasons. It may change to a multi-threaded default context in
  # the future.
  @[AlwaysInline]
  def self.default : ExecutionContext
    @@default.not_nil!("expected default execution context to have been setup")
  end

  # :nodoc:
  def self.init_default_context : Nil
    @@default = SingleThreaded.default
    @@monitor = Monitor.new
  end

  # Returns the number of threads to start in the default multi threaded
  # execution context. Respects the `CRYSTAL_WORKERS` environment variable
  # and otherwise returns the potential parallelism of the CPU (number of
  # hardware threads).
  #
  # Currently unused because the default context is single threaded for
  # now (this might change later with compilation flags).
  def self.default_workers_count : Int32
    ENV["CRYSTAL_WORKERS"]?.try(&.to_i?) || Math.min(System.cpu_count.to_i, 32)
  end

  # :nodoc:
  protected class_getter execution_contexts = Thread::LinkedList(ExecutionContext).new

  # :nodoc:
  property next : ExecutionContext?

  # :nodoc:
  property previous : ExecutionContext?

  # :nodoc:
  def self.unsafe_each(&) : Nil
    @@execution_contexts.try(&.unsafe_each { |execution_context| yield execution_context })
  end

  # Iterates all execution contexts.
  def self.each(&) : Nil
    execution_contexts.each { |execution_context| yield execution_context }
  end

  # Returns the `ExecutionContext` the current fiber is running in.
  @[AlwaysInline]
  def self.current : ExecutionContext
    Thread.current.execution_context
  end

  def self.current? : ExecutionContext?
    Thread.current.execution_context?
  end

  # :nodoc:
  #
  # Tells the current scheduler to suspend the current fiber and resume the
  # next runnable fiber. The current fiber will never be resumed; you're
  # responsible to reenqueue it.
  #
  # This method is safe as it only operates on the current `ExecutionContext`
  # and `Scheduler`.
  @[AlwaysInline]
  def self.reschedule : Nil
    Scheduler.current.reschedule
  end

  # :nodoc:
  #
  # Tells the current scheduler to suspend the current fiber and to resume
  # *fiber* instead. The current fiber will never be resumed; you're responsible
  # to reenqueue it.
  #
  # Raises `RuntimeError` if the fiber doesn't belong to the current execution
  # context.
  #
  # This method is safe as it only operates on the current `ExecutionContext`
  # and `Scheduler`.
  def self.resume(fiber : Fiber) : Nil
    if fiber.execution_context == current
      Scheduler.current.resume(fiber)
    else
      raise RuntimeError.new("Can't resume fiber from #{fiber.execution_context} into #{current}")
    end
  end

  # Creates a new fiber then calls `#enqueue` to add it to the execution
  # context.
  #
  # May be called from any `ExecutionContext` (i.e. must be thread-safe).
  def spawn(*, name : String? = nil, &block : ->) : Fiber
    Fiber.new(name, self, &block).tap { |fiber| enqueue(fiber) }
  end

  # :nodoc:
  #
  # Legacy support for the `same_thread` argument. Each execution context may
  # decide to support it or not (e.g. a single threaded context can accept it).
  abstract def spawn(*, name : String? = nil, same_thread : Bool, &block : ->) : Fiber

  # :nodoc:
  abstract def stack_pool : Fiber::StackPool

  # :nodoc:
  abstract def stack_pool? : Fiber::StackPool?

  # :nodoc:
  abstract def event_loop : Crystal::EventLoop

  # :nodoc:
  #
  # Enqueues a fiber to be resumed inside the execution context.
  #
  # May be called from any ExecutionContext (i.e. must be thread-safe). May also
  # be called from bare threads (outside of an ExecutionContext).
  abstract def enqueue(fiber : Fiber) : Nil
end
