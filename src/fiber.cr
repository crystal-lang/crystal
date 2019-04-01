require "c/sys/mman"
require "thread/linked_list"
require "./fiber/context"
require "./fiber/stack_pool"

# :nodoc:
@[NoInline]
fun _fiber_get_stack_top : Void*
  dummy = uninitialized Int32
  pointerof(dummy).as(Void*)
end

class Fiber
  @@fibers = Thread::LinkedList(Fiber).new

  # :nodoc:
  class_getter stack_pool = StackPool.new

  @context : Context
  @stack : Void*
  @resume_event : Crystal::Event?
  protected property stack_bottom : Void*
  property name : String?
  @alive = true
  @current_thread = Atomic(Thread?).new(nil)

  # :nodoc:
  property next : Fiber?

  # :nodoc:
  property previous : Fiber?

  # :nodoc:
  def self.inactive(fiber : Fiber)
    @@fibers.delete(fiber)
  end

  # :nodoc:
  def self.unsafe_each
    @@fibers.unsafe_each { |fiber| yield fiber }
  end

  def initialize(@name : String? = nil, &@proc : ->)
    @context = Context.new
    @stack, @stack_bottom = Fiber.stack_pool.checkout

    fiber_main = ->(f : Fiber) { f.run }

    # point to first addressable pointer on the stack (@stack_bottom points past
    # the stack because the stack grows down):
    stack_ptr = @stack_bottom - sizeof(Void*)

    # align the stack pointer to 16 bytes:
    stack_ptr = Pointer(Void*).new(stack_ptr.address & ~0x0f_u64)

    makecontext(stack_ptr, fiber_main)

    @@fibers.push(self)
  end

  # :nodoc:
  def initialize(@stack : Void*, thread)
    @proc = Proc(Void).new { }
    @context = Context.new(_fiber_get_stack_top)
    @stack_bottom = GC.current_thread_stack_bottom
    @name = "main"
    @current_thread.set(thread)
    @@fibers.push(self)
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
    Fiber.stack_pool.release(@stack)

    # Remove the current fiber from the linked list
    @@fibers.delete(self)

    # Delete the resume event if it was used by `yield` or `sleep`
    @resume_event.try &.free

    @alive = false
    Crystal::Scheduler.reschedule
  end

  def self.current
    Crystal::Scheduler.current_fiber
  end

  # The fiber's proc is currently running or didn't fully save its context. The
  # fiber can't be resumed.
  def running?
    @context.resumable == 0
  end

  # The fiber's proc is currently not running and fully saved its context. The
  # fiber can be resumed safely.
  def resumable?
    @context.resumable == 1
  end

  # The fiber's proc has terminated, and the fiber is now considered dead. The
  # fiber is impossible to resume, ever.
  def dead?
    @alive == false
  end

  def resume : Nil
    Crystal::Scheduler.resume(self)
  end

  # :nodoc:
  def resume_event
    @resume_event ||= Crystal::EventLoop.create_resume_event(self)
  end

  def self.yield
    Crystal::Scheduler.yield
  end

  def to_s(io : IO) : Nil
    io << "#<" << self.class.name << ":0x"
    object_id.to_s(16, io)
    if name = @name
      io << ": " << name
    end
    io << '>'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  # :nodoc:
  def push_gc_roots
    # Push the used section of the stack
    GC.push_stack @context.stack_top, @stack_bottom
  end
end
