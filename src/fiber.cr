require "crystal/system/thread_linked_list"
require "crystal/print_buffered"
require "./fiber/context"
require "./fiber/stack"

# :nodoc:
@[NoInline]
fun _fiber_get_stack_top : Void*
  dummy = uninitialized Int32
  pointerof(dummy).as(Void*)
end

# A `Fiber` is a light-weight execution unit managed by the Crystal runtime.
#
# It is conceptually similar to an operating system thread but with less
# overhead and completely internal to the Crystal process. The runtime includes
# a scheduler which schedules execution of fibers.
#
# A `Fiber` has a stack size of `8 MiB` which is usually also assigned
# to an operating system thread. But only `4KiB` are actually allocated at first
# so the memory footprint is very small.
#
# Communication between fibers is usually passed through `Channel`.
#
# ## Cooperative
#
# Fibers are cooperative. That means execution can only be drawn from a fiber
# when it offers it. It can't be interrupted in its execution at random.
# In order to make concurrency work, fibers must make sure to occasionally
# provide hooks for the scheduler to swap in other fibers.
# IO operations like reading from a file descriptor are natural implementations
# for this and the developer does not need to take further action on that. When
# IO access can't be served immediately by a buffer, the fiber will
# automatically wait and yield execution. When IO is ready it's going to be
# resumed through the event loop.
#
# When a computation-intensive task has none or only rare IO operations, a fiber
# should explicitly offer to yield execution from time to time using
# `Fiber.yield` to break up tight loops. The frequency of this call depends on
# the application and concurrency model.
#
# ## Event loop
#
# The event loop is responsible for keeping track of sleeping fibers waiting for
# notifications that IO is ready or a timeout reached. When a fiber can be woken,
# the event loop enqueues it in the scheduler
class Fiber
  @@fibers = uninitialized Thread::LinkedList(Fiber)

  protected def self.fibers : Thread::LinkedList(Fiber)
    @@fibers
  end

  # :nodoc:
  def self.init : Nil
    @@fibers = Thread::LinkedList(Fiber).new
  end

  @context : Context
  @stack : Stack
  @resume_event : Crystal::EventLoop::Event?
  @timeout_event : Crystal::EventLoop::Event?
  # :nodoc:
  property timeout_select_action : Channel::TimeoutAction?

  # The name of the fiber, used as internal reference.
  property name : String?

  @alive = true

  {% if flag?(:preview_mt) && !flag?(:execution_context) %}
    @current_thread = Atomic(Thread?).new(nil)
  {% end %}

  # :nodoc:
  property next : Fiber?

  # :nodoc:
  property previous : Fiber?

  {% if flag?(:execution_context) %}
    property! execution_context : ExecutionContext
  {% end %}

  # :nodoc:
  property list_next : Fiber?

  # :nodoc:
  def self.inactive(fiber : Fiber)
    fibers.delete(fiber)
  end

  # :nodoc:
  def self.unsafe_each(&)
    # nothing to iterate when @@fibers is nil + don't lazily allocate in a
    # method called from a GC collection callback!
    @@fibers.try(&.unsafe_each { |fiber| yield fiber })
  end

  # :nodoc:
  def self.each(&)
    fibers.each { |fiber| yield fiber }
  end

  {% begin %}
  # Creates a new `Fiber` instance.
  #
  # When the fiber is executed, it runs *proc* in its context.
  #
  # *name* is an optional and used only as an internal reference.
  def self.new(name : String? = nil, {% if flag?(:execution_context) %}execution_context : ExecutionContext = ExecutionContext.current,{% end %} &proc : ->) : self
    stack =
      {% if flag?(:interpreted) %}
        # the interpreter is managing the stacks
        Stack.new(Pointer(Void).null, Pointer(Void).null)
      {% elsif flag?(:execution_context) %}
        execution_context.stack_pool.checkout
      {% else %}
        Crystal::Scheduler.stack_pool.checkout
      {% end %}
    new(name, stack, {% if flag?(:execution_context) %}execution_context,{% end %} &proc)
  end

  # :nodoc:
  def initialize(@name : String?, @stack : Stack, {% if flag?(:execution_context) %}@execution_context : ExecutionContext = ExecutionContext.current,{% end %} &@proc : ->)
    @context = Context.new

    fiber_main = ->(f : Fiber) { f.run }
    stack_ptr = @stack.first_addressable_pointer
    makecontext(stack_ptr, fiber_main)

    Fiber.fibers.push(self)
  end
  {% end %}

  # :nodoc:
  def initialize(stack : Void*, thread)
    @proc = Proc(Void).new { }

    # TODO: should creating a new context for the main fiber also be platform specific?
    # It's the same for all platforms except for the interpreted mode.
    @context =
      {% if flag?(:interpreted) %}
        # In interpreted mode the stack_top variable actually points to a fiber
        Context.new(Crystal::Interpreter.current_fiber)
      {% else %}
        Context.new(_fiber_get_stack_top)
      {% end %}

    thread.gc_thread_handler, stack_bottom = GC.current_thread_stack_bottom
    @stack = Stack.new(stack, stack_bottom)

    @name = "main"

    {% if flag?(:preview_mt) && !flag?(:execution_context) %}
      @current_thread.set(thread)
    {% end %}

    Fiber.fibers.push(self)

    # we don't initialize @execution_context here (we may not have an execution
    # context yet), and we can't detect ExecutionContext.current (we may reach
    # an infinite recursion).
  end

  # :nodoc:
  def run
    GC.unlock_read

    @proc.call
  rescue ex
    if name = @name
      Crystal.print_buffered("Unhandled exception in spawn(name: %s)", name, exception: ex, to: STDERR)
    else
      Crystal.print_buffered("Unhandled exception in spawn", exception: ex, to: STDERR)
    end
  ensure
    # Remove the current fiber from the linked list
    Fiber.inactive(self)

    # Delete the resume event if it was used by `yield` or `sleep`
    @resume_event.try &.free
    @timeout_event.try &.free
    @timeout_select_action = nil

    # Additional cleanup (avoid stale references)
    @exec_recursive_hash = nil
    @exec_recursive_clone_hash = nil

    @alive = false

    # the interpreter is managing the stacks
    {% unless flag?(:interpreted) %}
      {% if flag?(:execution_context) %}
        # do not prematurely release the stack before we switch to another fiber
        if stack = Thread.current.dying_fiber(self)
          # we can however release the stack of a previously dying fiber (we
          # since swapped context)
          execution_context.stack_pool.release(stack)
        end
      {% else %}
        Crystal::Scheduler.stack_pool.release(@stack)
      {% end %}
    {% end %}

    Fiber.suspend
  end

  # Returns the current fiber.
  def self.current : Fiber
    Thread.current.current_fiber
  end

  # The fiber's proc is currently running or didn't fully save its context. The
  # fiber can't be resumed.
  def running? : Bool
    @context.resumable == 0
  end

  # The fiber's proc is currently not running and fully saved its context. The
  # fiber can be resumed safely.
  def resumable? : Bool
    @context.resumable == 1
  end

  # The fiber's proc has terminated, and the fiber is now considered dead. The
  # fiber is impossible to resume, ever.
  def dead? : Bool
    !@alive
  end

  # Immediately resumes execution of this fiber.
  #
  # There are no provisions for resuming the current fiber (where this
  # method is called). Unless it is explicitly added for rescheduling (for
  # example using `#enqueue`) the current fiber won't ever reach any instructions
  # after the call to this method.
  #
  # ```
  # fiber = Fiber.new do
  #   puts "in fiber"
  # end
  # fiber.resume
  # puts "never reached"
  # ```
  def resume : Nil
    {% if flag?(:execution_context) %}
      ExecutionContext.resume(self)
    {% else %}
      Crystal::Scheduler.resume(self)
    {% end %}
  end

  # Adds this fiber to the scheduler's runnables queue for the current thread.
  #
  # This signals to the scheduler that the fiber is eligible for being resumed
  # the next time it has the opportunity to reschedule to another fiber. There
  # are no guarantees when that will happen.
  def enqueue : Nil
    {% if flag?(:execution_context) %}
      execution_context.enqueue(self)
    {% else %}
      Crystal::Scheduler.enqueue(self)
    {% end %}
  end

  # :nodoc:
  def resume_event : Crystal::EventLoop::Event
    @resume_event ||= Crystal::EventLoop.current.create_resume_event(self)
  end

  # :nodoc:
  def timeout_event : Crystal::EventLoop::Event
    @timeout_event ||= Crystal::EventLoop.current.create_timeout_event(self)
  end

  # :nodoc:
  def timeout(timeout : Time::Span, select_action : Channel::TimeoutAction) : Nil
    @timeout_select_action = select_action
    timeout_event.add(timeout)
  end

  # :nodoc:
  def cancel_timeout : Nil
    return unless @timeout_select_action
    @timeout_select_action = nil
    @timeout_event.try &.delete
  end

  # :nodoc:
  #
  # The current fiber will resume after a period of time.
  # The timeout can be cancelled with `cancel_timeout`
  def self.timeout(timeout : Time::Span, select_action : Channel::TimeoutAction) : Nil
    Fiber.current.timeout(timeout, select_action)
  end

  # :nodoc:
  def self.cancel_timeout : Nil
    Fiber.current.cancel_timeout
  end

  struct TimeoutToken
    # :nodoc:
    getter value : UInt32

    def initialize(@value : UInt32)
    end
  end

  enum TimeoutResult
    EXPIRED
    CANCELED
  end

  private TIMEOUT_FLAG    = 1_u32
  private TIMEOUT_COUNTER = 2_u32

  @timeout = Atomic(UInt32).new(0_u32)

  # Suspends the current `Fiber` for *duration*.
  #
  # Yields a `TimeoutToken` before suspending the fiber. The token is required
  # to manually cancel the timeout before *duration* expires. See
  # `#resolve_timeout?` for details.
  #
  # The fiber will be automatically resumed after *duration* has elapsed, but it
  # may be resumed earlier if the timeout has been manually canceled, yet the
  # fiber will only ever be resumed once. The returned `TimeoutResult` can be
  # used to determine what happened and act accordingly, for example do some
  # cleanup or raise an exception if the timeout expired.
  #
  # ```
  # result = Fiber.timeout(5.seconds) do |cancelation_token|
  #   enqueue_waiter(Fiber.current, cancelation_token)
  # end
  #
  # if result.expired?
  #   dequeue_waiter(Fiber.current)
  # end
  # ```
  #
  # Consider `::sleep` if you don't need to cancel the timeout.
  def self.timeout(duration : Time::Span, & : TimeoutToken ->) : TimeoutResult
    timeout(until: Time.monotonic + duration) { |token| yield token }
  end

  # Identical to `.timeout` but suspending the fiber until an absolute time, as
  # per the monotonic clock, is reached.
  #
  # For example, we can retry something until 5 seconds have elapsed:
  #
  # ```
  # time = Time.monotonic + 5.seconds
  # loop do
  #   break if try_something?
  #   result = Fiber.timeout(until: time) { |token| add_waiter(token) }
  #   raise "timeout" if result.expired?
  # end
  # ```
  def self.timeout(*, until time : Time::Span, & : TimeoutToken ->) : TimeoutResult
    token = Fiber.current.create_timeout
    yield token
    result = Crystal::EventLoop.current.timeout(time, token)
    result ? TimeoutResult::EXPIRED : TimeoutResult::CANCELED
  end

  # Sets the timeout flag and increments the counter to avoid ABA issues with
  # parallel threads trying to resolve the timeout while the timeout was unset
  # then set again (new timeout). Since the current fiber is the only one that
  # can set the timeout, we can merely set the atomic (no need for CAS).
  protected def create_timeout : TimeoutToken
    value = (@timeout.get(:relaxed) | TIMEOUT_FLAG) &+ TIMEOUT_COUNTER
    @timeout.set(value, :relaxed)
    TimeoutToken.new(value)
  end

  # Tries to resolve the timeout previously set on `Fiber` using the cancelation
  # *token*. See `Fiber.timeout` for details on setting the timeout.
  #
  # Returns true when the timeout has been resolved, false otherwise.
  #
  # The caller that succeeded to resolve the timeout owns the fiber and must
  # eventually enqueue it. Failing to do so means that the fiber will never be
  # resumed.
  #
  # A caller that failed to resolve the timeout must skip the fiber. Trying to
  # enqueue the fiber would lead the fiber to be resumed twice!
  #
  # ```
  # require "wait_group"
  #
  # WaitGroup.wait do |wg|
  #   cancelation_token = nil
  #
  #   suspended_fiber = wg.spawn do
  #     result = Fiber.timeout(5.seconds) do |token|
  #       # save the token so another fiber can try to cancel the timeout
  #       cancelation_token = token
  #     end
  #
  #     # prints either EXPIRED or CANCELED
  #     puts result
  #   end
  #
  #   sleep rand(4..6).seconds
  #
  #   # let's try to cancel the timeout
  #   if suspended_fiber.resolve_timeout?(cancelation_token.not_nil!)
  #     # canceled: we must enqueue the fiber
  #     suspended_fiber.enqueue
  #   end
  # end
  # ```
  def resolve_timeout?(token : TimeoutToken) : Bool
    _, success = @timeout.compare_and_set(token.value, token.value & ~TIMEOUT_FLAG, :relaxed, :relaxed)
    success
  end

  # Yields to the scheduler and allows it to swap execution to other
  # waiting fibers.
  #
  # This is equivalent to `sleep 0.seconds`. It gives the scheduler an option
  # to interrupt the current fiber's execution. If no other fibers are ready to
  # be resumed, it immediately resumes the current fiber.
  #
  # This method is particularly useful to break up tight loops which are only
  # computation intensive and don't offer natural opportunities for swapping
  # fibers as with IO operations.
  #
  # ```
  # counter = 0
  # spawn name: "status" do
  #   loop do
  #     puts "Status: #{counter}"
  #     sleep(2.seconds)
  #   end
  # end
  #
  # while counter < Int32::MAX
  #   counter += 1
  #   if counter % 1_000_000 == 0
  #     # Without this, there would never be an opportunity to resume the status fiber
  #     Fiber.yield
  #   end
  # end
  # ```
  def self.yield : Nil
    Crystal.trace :sched, "yield"

    # TODO: Fiber switching and evloop for wasm32
    {% unless flag?(:wasi) %}
      Crystal::EventLoop.current.sleep(0.seconds)
    {% end %}
  end

  # Suspends execution of the current fiber indefinitely.
  #
  # Unlike `Fiber.yield` the current fiber is not automatically
  # reenqueued and can only be resumed with an explicit call to `#enqueue`.
  #
  # This is equivalent to `sleep` without a time.
  #
  # This method is meant to be used in concurrency primitives. It's particularly
  # useful if the fiber needs to wait  for something to happen (for example an IO
  # event, a message is ready in a channel, etc.) which triggers a re-enqueue.
  def self.suspend : Nil
    {% if flag?(:execution_context) %}
      ExecutionContext.reschedule
    {% else %}
      Crystal::Scheduler.reschedule
    {% end %}
  end

  def to_s(io : IO) : Nil
    io << "#<" << self.class.name << ":0x"
    object_id.to_s(io, 16)
    if name = @name
      io << ": " << name
    end
    io << '>'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  # :nodoc:
  def push_gc_roots : Nil
    # Push the used section of the stack
    GC.push_stack @context.stack_top, @stack.bottom
  end

  {% if flag?(:preview_mt) && !flag?(:execution_context) %}
    # :nodoc:
    def set_current_thread(thread = Thread.current) : Thread
      @current_thread.set(thread)
    end

    # :nodoc:
    def get_current_thread : Thread?
      @current_thread.lazy_get
    end
  {% end %}

  # :nodoc:
  #
  # See `Reference#exec_recursive` for details.
  def exec_recursive_hash
    @exec_recursive_hash ||= Hash({UInt64, Symbol}, Nil).new
  end

  # :nodoc:
  #
  # See `Reference#exec_recursive_clone` for details.
  def exec_recursive_clone_hash
    @exec_recursive_clone_hash ||= Hash(UInt64, UInt64).new
  end
end
