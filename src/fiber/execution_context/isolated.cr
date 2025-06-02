require "./scheduler"
require "../list"

module Fiber::ExecutionContext
  # Isolated execution context to run a single fiber.
  #
  # Concurrency and parallelism are disabled. The context guarantees that the
  # fiber will always run on the same system thread until it terminates; the
  # fiber owns the system thread for its whole lifetime.
  #
  # Keep in mind that the fiber will still run in parallel to other fibers
  # running in other execution contexts at the same time.
  #
  # Concurrency is disabled, so an isolated fiber can't spawn fibers into the
  # context, but it can spawn fibers into other execution contexts. Since it can
  # be inconvenient to pass an execution context around, calls to `::spawn` will
  # spawn a fiber into the specified *spawn_context* during initialization,
  # which defaults to `Fiber::ExecutionContext.default`.
  #
  # Isolated fibers can normally communicate with other fibers running in other
  # execution contexts using `Channel`, `WaitGroup` or `Mutex` for example. They
  # can also execute `IO` operations or `sleep` just like any other fiber.
  #
  # Calls that result in waiting (e.g. sleep, or socket read/write) will block
  # the thread since there are no other fibers to switch to. This in turn allows
  # to call anything that would block the thread without blocking any other
  # fiber.
  #
  # For example you can start an isolated fiber to run a blocking GUI loop,
  # transparently forward `::spawn` to the default context, then keep the main
  # fiber to wait until the GUI application quit:
  #
  # ```
  # gtk = Fiber::ExecutionContext::Isolated.new("Gtk") do
  #   Gtk.main
  # end
  # gtk.wait
  # ```
  class Isolated
    include ExecutionContext
    include ExecutionContext::Scheduler

    getter name : String

    @mutex = Thread::Mutex.new
    @condition = Thread::ConditionVariable.new
    protected getter thread : Thread
    protected getter main_fiber : Fiber

    # :nodoc:
    getter(event_loop : Crystal::EventLoop) do
      evloop = Crystal::EventLoop.create(parallelism: 1)
      evloop.register(self, index: 0)
      evloop
    end

    getter? running : Bool = true
    @enqueued = false
    @waiting = false

    @wait_list = Crystal::PointerLinkedList(Fiber::PointerLinkedListNode).new
    @exception : Exception?

    # Starts a new thread named *name* to execute *func*. Once *func* returns
    # the thread will terminate.
    def initialize(@name : String, @spawn_context : ExecutionContext = ExecutionContext.default, &@func : ->)
      @thread = uninitialized Thread
      @main_fiber = uninitialized Fiber
      @main_fiber = Fiber.new(@name, allocate_stack, self) { run }
      @thread = start_thread
      ExecutionContext.execution_contexts.push(self)
    end

    private def allocate_stack : Stack
      # no stack pool: we directly allocate a stack; it will be automatically
      # released when the thread is returned to the thread pool
      pointer = Crystal::System::Fiber.allocate_stack(StackPool::STACK_SIZE, protect: true)
      Stack.new(pointer, StackPool::STACK_SIZE, reusable: true)
    end

    private def start_thread : Thread
      ExecutionContext.thread_pool.checkout(self)
    end

    protected def thread=(@thread)
    end

    # :nodoc:
    def execution_context : Isolated
      self
    end

    # :nodoc:
    def stack_pool : Fiber::StackPool
      raise RuntimeError.new("No stack pool for isolated contexts")
    end

    # :nodoc:
    def stack_pool? : Fiber::StackPool?
    end

    def spawn(*, name : String? = nil, &block : ->) : Fiber
      @spawn_context.spawn(name: name, &block)
    end

    # :nodoc:
    def spawn(*, name : String? = nil, same_thread : Bool, &block : ->) : Fiber
      raise ArgumentError.new("#{self.class.name}#spawn doesn't support same_thread:true") if same_thread
      @spawn_context.spawn(name: name, &block)
    end

    # :nodoc:
    def enqueue(fiber : Fiber) : Nil
      Crystal.trace :sched, "enqueue", fiber: fiber, context: self

      unless fiber == @main_fiber
        raise RuntimeError.new("Concurrency is disabled in isolated contexts")
      end

      @mutex.synchronize do
        raise RuntimeError.new("Can't resume dead fiber") unless @running

        @enqueued = true

        if @waiting
          # wake up the blocked thread
          @waiting = false

          if event_loop = @event_loop
            event_loop.interrupt
          else
            @condition.signal
          end
        else
          # race: enqueued before the other thread started waiting
        end
      end
    end

    protected def reschedule : Nil
      Crystal.trace :sched, "reschedule"

      if @main_fiber.dead?
        ExecutionContext.thread_pool.checkin
        return # actually unreachable
      end

      if event_loop = @event_loop
        wait_for(event_loop)
      else
        park_thread
      end

      Crystal.trace :sched, "resume"
    end

    private def park_thread
      @mutex.synchronize do
        loop do
          return if check_enqueued?
          @waiting = true
          @condition.wait(@mutex)
        end
      end
    end

    private def wait_for(event_loop) : Nil
      loop do
        @mutex.synchronize do
          return if check_enqueued?
          @waiting = true
        end

        # wait on the event loop
        list = Fiber::List.new
        event_loop.run(pointerof(list), blocking: true)

        # restart if the evloop got interrupted
        next unless fiber = list.pop?

        # sanity check
        unless fiber == @main_fiber && list.empty?
          raise RuntimeError.new("Concurrency is disabled in isolated contexts")
        end

        break
      end

      # cleanup
      @mutex.synchronize do
        @waiting = false
        @enqueued = false
      end
    end

    private def check_enqueued?
      if @enqueued
        @enqueued = false
        @waiting = false
        true
      else
        false
      end
    end

    protected def resume(fiber : Fiber) : Nil
      # in theory we could resume @main_fiber, but this method may only be
      # called from the current execution context, which is @main_fiber; it
      # doesn't make any sense for a fiber to resume itself
      raise RuntimeError.new("Can't resume #{fiber} in #{self}")
    end

    private def run
      Crystal.trace :sched, "started"
      @func.call
    rescue exception
      @exception = exception
    ensure
      @mutex.synchronize do
        @running = false
        @wait_list.consume_each(&.value.enqueue)
      end

      begin
        @event_loop.try(&.unregister(self))
      ensure
        ExecutionContext.execution_contexts.delete(self)
      end
    end

    # Blocks the calling fiber until the isolated context fiber terminates.
    # Returns immediately if the isolated fiber has already terminated.
    # Re-raises unhandled exceptions raised by the fiber.
    #
    # For example:
    #
    # ```
    # ctx = Fiber::ExecutionContext::Isolated.new("test") do
    #   raise "fail"
    # end
    # ctx.wait # => re-raises "fail"
    # ```
    def wait : Nil
      if @running
        node = Fiber::PointerLinkedListNode.new(Fiber.current)
        running = @mutex.synchronize do
          @wait_list.push(pointerof(node)) if @running
          @running
        end
        Fiber.suspend if running
      end

      if exception = @exception
        raise exception
      end
    end

    # :nodoc:
    #
    # Simple alias to ease the transition from Thread.
    def join
      wait
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
      if @waiting
        "event-loop"
      elsif @running
        "running"
      else
        "shutdown"
      end
    end
  end
end
