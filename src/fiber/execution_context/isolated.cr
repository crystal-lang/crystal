require "./scheduler"
require "../list"

module Fiber::ExecutionContext
  # Isolated execution context. Runs a single thread with a single fiber.
  #
  # Concurrency is disabled within the thread: the fiber owns the thread and the
  # thread can only run this fiber. Keep in mind that the fiber will still run
  # in parallel to other fibers running in other execution contexts.
  #
  # The fiber can still spawn fibers into other execution contexts. Since it can
  # be inconvenient to pass an execution context around, calls to `::spawn` will
  # spawn a fiber into the specified *spawn_context* that defaults to the
  # default execution context.
  #
  # Isolated fibers can normally communicate with other fibers running in other
  # execution contexts using `Channel(T)`, `WaitGroup` or `Mutex` for example.
  # They can also execute IO operations or sleep just like any other fiber.
  #
  # Calls that result in waiting (e.g. sleep, or socket read/write) will block
  # the thread since there are no other fibers to switch to. This in turn allows
  # to call anything that would block the thread without blocking any other
  # fiber.
  #
  # You can for example use an isolated fiber to run a blocking GUI loop,
  # transparently forward `::spawn` to the default context, and eventually only
  # block the current fiber while waiting for the GUI application to quit:
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

    @mutex : Thread::Mutex
    protected getter thread : Thread
    @main_fiber : Fiber

    # :nodoc:
    getter event_loop : Crystal::EventLoop = Crystal::EventLoop.create

    getter? running : Bool = true
    @enqueued = false
    @waiting = false

    @wait_list = Crystal::PointerLinkedList(Fiber::PointerLinkedListNode).new
    @exception : Exception?

    # Starts a new thread named *name* to execute *func*. Once *func* returns
    # the thread will terminate.
    def initialize(@name : String, @spawn_context : ExecutionContext = ExecutionContext.default, &@func : ->)
      @mutex = Thread::Mutex.new
      @thread = uninitialized Thread
      @main_fiber = uninitialized Fiber
      @thread = start_thread
      ExecutionContext.execution_contexts.push(self)
    end

    private def start_thread : Thread
      Thread.new(name: @name) do |thread|
        @thread = thread
        thread.execution_context = self
        thread.scheduler = self
        thread.main_fiber.name = @name
        @main_fiber = thread.main_fiber
        run
      end
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
          @event_loop.interrupt
        else
          # race: enqueued before the other thread started waiting
        end
      end
    end

    protected def reschedule : Nil
      Crystal.trace :sched, "reschedule"

      loop do
        @mutex.synchronize do
          # race: another thread already re-enqueued the fiber
          if @enqueued
            Crystal.trace :sched, "resume"
            @enqueued = false
            @waiting = false
            return
          end
          @waiting = true
        end

        # wait on the event loop
        list = Fiber::List.new
        @event_loop.run(pointerof(list), blocking: true)

        if fiber = list.pop?
          break if fiber == @main_fiber && list.empty?
          raise RuntimeError.new("Concurrency is disabled in isolated contexts")
        end

        # the evloop got interrupted: restart
      end

      # cleanup
      @mutex.synchronize do
        @waiting = false
        @enqueued = false
      end

      Crystal.trace :sched, "resume"
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
      ExecutionContext.execution_contexts.delete(self)
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
