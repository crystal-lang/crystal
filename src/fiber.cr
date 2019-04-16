require "c/sys/mman"
require "thread/linked_list"
require "./fiber/stack_pool"

# Load the arch-specific methods to create a context and to swap from one
# context to another one. There are two methods: `Fiber#makecontext` and
# `Fiber.swapcontext`.
#
# - `Fiber.swapcontext(current_stack_ptr : Void**, dest_stack_ptr : Void*)
#
#   A fiber context switch in Crystal is achieved by calling a symbol (which
#   must never be inlined) that will push the callee-saved registers (sometimes
#   FPU registers and others) on the stack, saving the current stack pointer at
#   location pointed by `current_stack_ptr` (the current fiber is now paused)
#   then loading the `dest_stack_ptr` pointer into the stack pointer register
#   and popping previously saved registers from the stack. Upon return from the
#   symbol the new fiber is resumed since we returned/jumped to the calling
#   symbol.
#
#   Details are arch-specific. For example:
#   - which registers must be saved, the callee-saved are sometimes enough (X86)
#     but some archs need to save the FPU register too (ARMHF);
#   - a simple return may be enough (X86), but sometimes an explicit jump is
#     required to not confuse the stack unwinder (ARM);
#   - and more.
#
#   For the initial resume, the register holding the first parameter must be set
#   (see makecontext below) and thus must also be saved/restored.
#
# - `Fiber#makecontext(stack_ptr : Void*, fiber_main : Fiber ->)`
#
#   `makecontext` is responsible to reserve and initialize space on the stack
#   for the initial context and save the initial `@stack_top` pointer. The first
#   time a fiber is resumed, the `fiber_main` proc must be called, passing
#   `self` as its first argument.
require "./fiber/*"

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

  @stack : Void*
  @resume_event : Crystal::Event?
  @stack_top = Pointer(Void).null
  protected property stack_top : Void*
  protected property stack_bottom : Void*
  property name : String?

  # :nodoc:
  property next : Fiber?

  # :nodoc:
  property previous : Fiber?

  # :nodoc:
  def self.inactive(fiber : Fiber)
    @@fibers.delete(fiber)
  end

  def initialize(@name : String? = nil, &@proc : ->)
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
  def initialize(@stack : Void*)
    @proc = Proc(Void).new { }
    @stack_top = _fiber_get_stack_top
    @stack_bottom = GC.stack_bottom
    @name = "main"

    @@fibers.push(self)
  end

  # :nodoc:
  def run
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

    Crystal::Scheduler.reschedule
  end

  def self.current
    Crystal::Scheduler.current_fiber
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

  protected def push_gc_roots
    # Push the used section of the stack
    GC.push_stack @stack_top, @stack_bottom
  end

  # pushes the stack of pending fibers when the GC wants to collect memory:
  GC.before_collect do
    current = Fiber.current

    @@fibers.unsafe_each do |fiber|
      fiber.push_gc_roots unless fiber == current
    end
  end
end
