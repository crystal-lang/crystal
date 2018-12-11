require "c/sys/mman"
{% unless flag?(:win32) %}
require "c/sys/resource"
{% end %}
require "thread/linked_list"

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
  STACK_SIZE = 8 * 1024 * 1024

  @@fibers = Thread::LinkedList(Fiber).new
  @@stack_pool = [] of Void*

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
    @stack = Fiber.allocate_stack
    @stack_bottom = @stack + STACK_SIZE

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
  def initialize
    @proc = Proc(Void).new { }
    @stack_top = _fiber_get_stack_top
    @stack_bottom = GC.stack_bottom
    @name = "main"

    # Determine location of the top of the stack.
    # The technique here works only for the main stack on a POSIX platform.
    # TODO: implement for Windows with GetCurrentThreadStackLimits
    # TODO: implement for pthreads using
    #    linux-glibc/musl: pthread_getattr_np
    #              macosx: pthread_get_stackaddr_np, pthread_get_stacksize_np
    #             freebsd: pthread_attr_get_np
    #             openbsd: pthread_stackseg_np
    @stack = Pointer(Void).null
    {% unless flag?(:win32) %}
      if LibC.getrlimit(LibC::RLIMIT_STACK, out rlim) == 0
        stack_size = rlim.rlim_cur
        @stack = Pointer(Void).new(@stack_bottom.address - stack_size)
      end
    {% end %}

    @@fibers.push(self)
  end

  protected def self.allocate_stack
    if pointer = @@stack_pool.pop?
      return pointer
    end

    flags = LibC::MAP_PRIVATE | LibC::MAP_ANON
    {% if flag?(:openbsd) && !flag?(:"openbsd6.2") %}
      flags |= LibC::MAP_STACK
    {% end %}

    LibC.mmap(nil, Fiber::STACK_SIZE, LibC::PROT_READ | LibC::PROT_WRITE, flags, -1, 0).tap do |pointer|
      raise Errno.new("Cannot allocate new fiber stack") if pointer == LibC::MAP_FAILED

      {% if flag?(:linux) %}
        LibC.madvise(pointer, Fiber::STACK_SIZE, LibC::MADV_NOHUGEPAGE)
      {% end %}

      LibC.mprotect(pointer, 4096, LibC::PROT_NONE)
    end
  end

  # :nodoc:
  def self.stack_pool_collect
    return if @@stack_pool.size == 0
    free_count = @@stack_pool.size > 1 ? @@stack_pool.size / 2 : 1
    free_count.times do
      stack = @@stack_pool.pop
      LibC.munmap(stack, Fiber::STACK_SIZE)
    end
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
    @@stack_pool << @stack

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

  def to_s(io)
    io << "#<" << self.class.name << ":0x"
    object_id.to_s(16, io)
    if name = @name
      io << ": " << name
    end
    io << '>'
  end

  def inspect(io)
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
