require "crystal/system/thread_linked_list"
require "./fiber/context"
require "./fiber/stack_pool"

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
  # :nodoc:
  protected class_getter(fibers) { Thread::LinkedList(Fiber).new }

  # :nodoc:
  class_getter stack_pool = StackPool.new

  @context : Context
  @stack : Void*
  @resume_event : Crystal::Event?
  @timeout_event : Crystal::Event?
  # :nodoc:
  property timeout_select_action : Channel::TimeoutAction?
  protected property stack_bottom : Void*

  # The name of the fiber, used as internal reference.
  property name : String?

  @alive = true
  @current_thread = Atomic(Thread?).new(nil)

  # :nodoc:
  property next : Fiber?

  # :nodoc:
  property previous : Fiber?

  # :nodoc:
  def self.inactive(fiber : Fiber)
    fibers.delete(fiber)
  end

  # :nodoc:
  def self.unsafe_each
    fibers.unsafe_each { |fiber| yield fiber }
  end

  # Creates a new `Fiber` instance.
  #
  # When the fiber is executed, it runs *proc* in its context.
  #
  # *name* is an optional and used only as an internal reference.
  def initialize(@name : String? = nil, &@proc : ->)
    @context = Context.new
    @stack, @stack_bottom = Fiber.stack_pool.checkout

    fiber_main = ->(f : Fiber) { f.run }

    # FIXME: This line shouldn't be necessary (#7975)
    stack_ptr = nil
    {% if flag?(:win32) %}
      # align stack bottom to 16 bytes
      @stack_bottom = Pointer(Void).new(@stack_bottom.address & ~0x0f_u64)

      # It's the caller's responsibility to allocate 32 bytes of "shadow space" on the stack right
      # before calling the function (regardless of the actual number of parameters used)

      stack_ptr = @stack_bottom - sizeof(Void*) * 6
    {% else %}
      # point to first addressable pointer on the stack (@stack_bottom points past
      # the stack because the stack grows down):
      stack_ptr = @stack_bottom - sizeof(Void*)
    {% end %}

    # align the stack pointer to 16 bytes:
    stack_ptr = Pointer(Void*).new(stack_ptr.address & ~0x0f_u64)

    makecontext(stack_ptr, fiber_main)

    Fiber.fibers.push(self)
  end

  # :nodoc:
  def initialize(@stack : Void*, thread)
    @proc = Proc(Void).new { }
    @context = Context.new(_fiber_get_stack_top)
    thread.gc_thread_handler, @stack_bottom = GC.current_thread_stack_bottom
    @name = "main"
    @current_thread.set(thread)
    Fiber.fibers.push(self)
  end

  # :nodoc:
  def run
    GC.unlock_read
    @proc.call
  rescue ex
    if name = @name
      STDERR.print "Unhandled exception in spawn(name: #{name}): "
    else
      STDERR.print "Unhandled exception in spawn: "
    end
    ex.inspect_with_backtrace(STDERR)
    STDERR.flush
  ensure
    {% if flag?(:preview_mt) %}
      Crystal::Scheduler.enqueue_free_stack @stack
    {% else %}
      Fiber.stack_pool.release(@stack)
    {% end %}

    # Remove the current fiber from the linked list
    Fiber.fibers.delete(self)

    # Delete the resume event if it was used by `yield` or `sleep`
    @resume_event.try &.free
    @timeout_event.try &.free
    @timeout_select_action = nil

    @alive = false
    Crystal::Scheduler.reschedule
  end

  # Returns the current fiber.
  def self.current : Fiber
    Crystal::Scheduler.current_fiber
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
    @alive == false
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
    Crystal::Scheduler.resume(self)
  end

  # Adds this fiber to the scheduler's runnables queue for the current thread.
  #
  # This signals to the scheduler that the fiber is eligible for being resumed
  # the next time it has the opportunity to reschedule to an other fiber. There
  # are no guarantees when that will happen.
  def enqueue : Nil
    Crystal::Scheduler.enqueue(self)
  end

  # :nodoc:
  def resume_event : Crystal::Event
    @resume_event ||= Crystal::EventLoop.create_resume_event(self)
  end

  # :nodoc:
  def timeout_event : Crystal::Event
    @timeout_event ||= Crystal::EventLoop.create_timeout_event(self)
  end

  # :nodoc:
  def timeout(timeout : Time::Span?, select_action : Channel::TimeoutAction? = nil) : Nil
    @timeout_select_action = select_action
    timeout_event.add(timeout)
  end

  # :nodoc:
  def cancel_timeout : Nil
    @timeout_select_action = nil
    @timeout_event.try &.delete
  end

  # The current fiber will resume after a period of time
  # and have the property `timed_out` set to true.
  # The timeout can be cancelled with `cancel_timeout`
  def self.timeout(timeout : Time::Span?, select_action : Channel::TimeoutAction? = nil) : Nil
    Crystal::Scheduler.current_fiber.timeout(timeout, select_action)
  end

  def self.cancel_timeout : Nil
    Crystal::Scheduler.current_fiber.cancel_timeout
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
    Crystal::Scheduler.yield
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
    GC.push_stack @context.stack_top, @stack_bottom
  end
end
